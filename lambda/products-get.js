exports.handler = async () => {
  return {
    statusCode: 200,
    body: JSON.stringify({ message: "products-get-service OK" })
  };
};
