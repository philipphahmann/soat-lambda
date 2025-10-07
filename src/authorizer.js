const jwt = require("jsonwebtoken");
const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");

// Nome do segredo passado pela variável de ambiente do Terraform
const SECRET_NAME = process.env.PUBLIC_KEY_SECRET_NAME || "secret/jwt/lambda_authorizer";
const AWS_REGION = process.env.AWS_REGION || "us-east-1";

// Cria um cliente para o Secrets Manager
const client = new SecretsManagerClient({ region: AWS_REGION });

// Variável para armazenar a chave pública em cache
let publicKeyCache = null;

/**
 * Busca a chave pública no Secrets Manager.
 * Implementa um cache simples para evitar chamadas repetidas.
 */
async function getPublicKey() {
    if (publicKeyCache) {
        console.log("✅ Chave pública retornada do cache.");
        return publicKeyCache;
    }

    try {
        console.log(`Buscando segredo '${SECRET_NAME}' no Secrets Manager...`);
        const command = new GetSecretValueCommand({ SecretId: SECRET_NAME });
        const response = await client.send(command);
        
        const secret = response.SecretString;
        publicKeyCache = secret; // Armazena em cache
        
        console.log("✅ Chave pública obtida e armazenada em cache.");
        return secret;

    } catch (error) {
        console.error("❌ Erro ao buscar chave pública no Secrets Manager:", error);
        throw new Error("Não foi possível obter a chave pública para verificação.");
    }
}

exports.handler = async (event) => {
    const token = event.headers?.Authorization?.replace("Bearer ", "");
    if (!token) {
        console.error("❌ Nenhum token fornecido");
        return generatePolicy("unauthorized", "Deny", event.methodArn);
    }

    try {
        const publicKey = await getPublicKey();

        const decoded = await new Promise((resolve, reject) => {
            // Usa a chave pública obtida do Secrets Manager para verificar o token
            jwt.verify(token, publicKey, { algorithms: ["RS256"] }, (err, decoded) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(decoded);
                }
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