const jwt = require("jsonwebtoken");
const jwksClient = require("jwks-rsa");

const JWKS_URI = process.env.JWKS_URI || "http://localhost:8080/.well-known/jwks.json";

const client = jwksClient({
    jwksUri: JWKS_URI,
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 10,
});

function getKey(header, callback) {
    client.getSigningKey(header.kid, (err, key) => {
        if (err) return callback(err);
        const signingKey = key.getPublicKey();
        callback(null, signingKey);
    });
}

exports.handler = async (event) => {
    const token = event.headers?.Authorization?.replace("Bearer ", "");
    if (!token) {
        console.error("❌ Nenhum token fornecido");
        return generatePolicy("unauthorized", "Deny", event.methodArn);
    }

    try {
        const decoded = await new Promise((resolve, reject) => {
            jwt.verify(token, getKey, { algorithms: ["RS256"] }, (err, decoded) => {
                if (err) reject(err);
                else resolve(decoded);
            });
        });

        console.log("✅ Token válido:", decoded);

        return {
            principalId: decoded.sub || "user",
            policyDocument: {
                Version: "2012-10-17",
                Statement: [
                    {
                        Action: "execute-api:Invoke",
                        Effect: "Allow",
                        Resource: event.methodArn,
                    },
                ],
            },
            context: {
                user: decoded.sub,
                roles: decoded.roles?.join(",") || "USER",
            },
        };
    } catch (err) {
        console.error("❌ Token inválido:", err.message);
        return generatePolicy("unauthorized", "Deny", event.methodArn);
    }
};

function generatePolicy(principalId, effect, resource) {
    return {
        principalId,
        policyDocument: {
            Version: "2012-10-17",
            Statement: [
                {
                    Action: "execute-api:Invoke",
                    Effect: effect,
                    Resource: resource,
                },
            ],
        },
    };
}
