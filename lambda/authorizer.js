const jwt = require("jsonwebtoken");

exports.handler = async (event) => {
  const token = event.headers?.Authorization?.replace("Bearer ", "");

  try {
    const decoded = jwt.verify(token, "9oub4aB30SWM4GLVu/u5SK2pnRBtLuvP1MsCb5jWcuY=");

    return {
      principalId: decoded.sub || "user",
      policyDocument: {
        Version: "2012-10-17",
        Statement: [
          {
            Action: "execute-api:Invoke",
            Effect: "Allow",
            Resource: event.methodArn
          }
        ]
      },
      context: {
        user: decoded.sub,
        roles: decoded.roles?.join(",") || "USER"
      }
    };
  } catch (err) {
    console.error("Erro ao validar token", err);
    return {
      principalId: "unauthorized",
      policyDocument: {
        Version: "2012-10-17",
        Statement: [
          {
            Action: "execute-api:Invoke",
            Effect: "Deny",
            Resource: event.methodArn
          }
        ]
      }
    };
  }
};