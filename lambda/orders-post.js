exports.handler = async () => {
  return {
    statusCode: 200,
    body: JSON.stringify({ message: "orders-post-service OK" })
  };
};
