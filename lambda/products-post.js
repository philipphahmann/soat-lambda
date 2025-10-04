exports.handler = async () => {
  return {
    statusCode: 200,
    body: JSON.stringify({ message: "products-post-service OK" })
  };
};
