const BUCKET_NAME = "woo-cf-test";
const SDK_INDEX_NAME = "test-sdk.js";
const WEB_INDEX_NAME = "index.html";
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
const s3 = new AWS.S3();

// S3에서 weight.json 파일 읽기 함수
async function getWeights(path) {
  try {
    const params = {
      Bucket: `${BUCKET_NAME}/${path}`,
      Key: "weight.json",
    };

    const data = await s3.getObject(params).promise();

    return JSON.parse(data.Body.toString());
  } catch (error) {
    console.error("weight.json 파일 읽기 실패:", error);
    return { weights: {} }; // 기본값 반환
  }
}

exports.handler = async (event, context, callback) => {
  // 그대로 패스
  const req = event.Records[0].cf.request;
  const path = req.uri;
  // 요청 경로에서 SDK 종류와 타입 추출
  const fileName = path.split("/").pop();
  const pathParts = path.split("/").filter((part) => part);
  // ex) /widget/sdk
  // ex) /widget/web/1.0.0
  const featureType = pathParts[0] || ""; // 첫번째 path: 기능 종류 , ex) widget, live, chat, et
  const clientType = pathParts[1] || ""; // 두번째 path: sdk인지 web인지 , ex) sdk
  let version = pathParts[2] || ""; // 세번째 path: 버전 , ex) 1.0.0

  console.log(`요청 경로: ${featureType}, ${clientType}, ${version}`);

  // if (clientType === "sdk") {
  //   // 간단한 가중치 처리
  //   const weights = await getWeights(featureType);
  //   const random = Math.random() * 100;

  //   req.uri = `${featureType}/${version}/${clientType}/${SDK_INDEX_NAME}`;
  // } else if (clientType === "web") {
  //   // React SPA 라우팅 처리
  //   const fileExtension = path.split(".").pop();
  //   const basePath = `${featureType}/${version}/${clientType}`;

  //   if (STATIC_EXTENSIONS.includes(fileExtension)) {
  //     // 정적 파일은 실제 경로로
  //     req.uri = path;
  //   } else {
  //     // React 라우트는 basePath의 index.html로
  //     req.uri = `/${basePath}/${WEB_INDEX_NAME}`;
  //   }
  // } else {
  //   req.uri = `/index.html`;
  // }
  req.uri = `/widget/1.0.0/index.html`;
  return callback(null, req);
};
