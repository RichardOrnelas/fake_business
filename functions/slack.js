const https = require("https");
const util = require("util");
// const config = require("./config");

exports.handler = function(event, context) {
  console.log(JSON.stringify(event, null, 2));
  console.log("From SNS:", event.Records[0].Sns.Message);

  const postData = {
    // "channel": config.slack.channel,
    "username": "Deep Seas Ops",
    "text": "*" + event.Records[0].Sns.Subject + "*",
    // "icon_emoji": config.slack.icon_emoji
  };

  var message = event.Records[0].Sns.Message;
  var severity = "";

  if (message.startsWith("ERROR")) {
    severity = "danger";
  }
  else if (message.startsWith("WARNING")) {
    severity = "warning";
  }
  else {
    severity = "good";
  }

  console.log("Message: " + message);
  console.log("Severity: " + severity);


  postData.attachments = [
    {
      "color": severity,
      "text": message
    }
  ];

  var options = {
    method: "POST",
    hostname: 'hooks.slack.com',
    port: 443,
    path: process.env.SLACK_WEBHOOK
  };

  var req = https.request(options, function (res) {
    res.setEncoding("utf8");
    res.on("data", function (chunk) {
      context.done(null);
    });
  });

  console.log("postData" + postData);
  req.on("error", function (e) {
    console.log("problem with request: " + e.message);
  });

  req.write(util.format("%j", postData));
  req.end();
};

