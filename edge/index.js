// 아주 단순한 Lambda@Edge (viewer-request)
exports.handler = async (event, context, callback) => {
  // 그대로 패스
  const req = event.Records[0].cf.request;

  // 헤더 추가 예시
  req.headers["x-custom-header"] = [{ key: "x-custom-header", value: "ok" }];

  return callback(null, req);
};
