// const { S3Client, GetObjectCommand } = require("@aws-sdk/client-s3");

const SDK_NAME = "test-sdk.js";
const STATIC_EXTENSIONS = [
  "css",
  "js",
  "png",
  "jpg",
  "jpeg",
  "gif",
  "svg",
  "ico",
  "woff",
  "woff2",
  "ttf",
  "eot",
];

exports.handler = async (event, context, callback) => {
  try {
    // 그대로 패스
    const req = event.Records[0].cf.request;
    const path = req.uri.split("/").filter((item) => item !== "");
    const featureType = path[0]; // widget, shortform
    let version = path[1]; // sdk는 버전 명시 X, web는 버전 명시 O
    const fileName = path[path.length - 1];
    const fileExtension = fileName.split(".")[1];
    console.log("path", path);
    console.log("featureType", featureType);
    console.log("version", version);

    // 헤더 추가 예시
    req.headers["x-custom-header"] = [{ key: "x-custom-header", value: "ok" }];

    if (fileName === SDK_NAME) {
      if (version == null) {
        version = "1.0.0";
      }
      req.uri = `/${featureType}/${version}/sdk/${SDK_NAME}`;
    } else {
      if (STATIC_EXTENSIONS.includes(fileExtension)) {
        // 버전과 클라이언트 타입 경로 순서 변경
        req.uri = req.uri;
      } else {
        req.uri = `/${featureType}/${version}/index.html`;
      }
    }

    console.log("req.uri", req.uri);

    return callback(null, req);
  } catch (error) {
    console.log("error", error);
    req.uri = "/widget/1.0.0/error.html";
    return callback(null, req);
  }
};
