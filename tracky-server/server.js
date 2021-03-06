/*

MIT License

Copyright (c) 2021 Kacper Marcinkiewicz

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/


//Check are required packages installed
try {
    require('express')
    require('body-parser')
    require('fs')
    require('path')
    require('mongodb')
    require('lowdb')
    require('readline-sync')
    require('https')
    require('ws')
} catch (e) {
    return console.log(`\n   You don't have required packages! \n\n   Use "npm i" to install them! \n\n`)
}

var https = require('https');
const express = require('express')
const bodyParser = require('body-parser')
const fs = require('fs')
const readline = require('readline-sync')


//#region Config variables
// var adminPassword = randomFromZeroToNine() + randomFromZeroToNine() + randomFromZeroToNine() + randomFromZeroToNine() //Generate 4 random numbers
var mongoDatabaseConnectionUrl = "mongodb://"
var apiPort = 5000;
var chatPort = 5001;
var minRequiredAppVersion = "0.0.0"
var httpsEnabled = false;
var privateKey  = ""
var certificate = ""
//#endregion

//#region Get data from config
try {
    var cfg = fs.readFileSync("./config.json")
    cfg = JSON.parse(cfg)
    //adminPassword = cfg.adminPassword
    mongoDatabaseConnectionUrl = cfg.mongoDatabaseConnectionUrl
    apiPort = cfg.apiPort
    chatPort = cfg.chatPort
    minRequiredAppVersion = cfg.minRequiredAppVersion
    httpsEnabled = cfg.httpsEnabled
    if(httpsEnabled){
        privateKey = fs.readFileSync(cfg.httpsPrivateKey, 'utf8');
        certificate = fs.readFileSync(cfg.httpsCertificate, 'utf8');
    }    
} catch (e) {
    //Create config if not exist
    if (!fs.existsSync("./config.json")) {
        var data = {
            //adminPassword: adminPassword,
            mongoDatabaseConnectionUrl: mongoDatabaseConnectionUrl,
            apiPort: apiPort,
            chatPort: chatPort,
            minRequiredAppVersion: minRequiredAppVersion,
            httpsEnabled: httpsEnabled,
            httpsPrivateKey: privateKey,
            httpsCertificate: certificate,
        }
        data = JSON.stringify(data, null, 2)
        fs.writeFileSync("./config.json", data)
        console.log("Config file created, you can now edit it")
        return readline.keyInPause("\nProgram ended...")
    } else {
        console.log("Error occurred: " + e + "\n\nYou can try to delete config file if you can't fix this error")
        return readline.keyInPause("\nProgram ended...")
    }
}
//#endregion

if(!apiPort) return console.log("You must set apiPort in config.json!") 
if(!mongoDatabaseConnectionUrl || mongoDatabaseConnectionUrl == "mongodb://") return console.log("You must set mongoDatabaseConnectionUrl in config.json!") 

const chat = require('./chat')

const low = require('lowdb')
const FileSync = require('lowdb/adapters/FileSync')
const infoAdapter = new FileSync(`info.json`)
const infoDb = low(infoAdapter)

// *****************************
// *   API starts from there   *
// *****************************

var onlyApi = false;
var onlyChat = false;
process.argv.forEach((arg) => {
    if(arg.toLocaleLowerCase() == "--only-chat") onlyChat = true;
    if(arg.toLocaleLowerCase() == "--only-api") onlyApi = true;
})

infoDb.defaults({ title: "", message: ""}).write() //default variables for database

const app = express();

if(!onlyChat){
    // Set up the express app
    app.use(bodyParser.json({limit: '50mb'}));
    app.use(bodyParser.urlencoded({limit: '50mb', extended: true}));
    
    //Routes API v1
    var routes_v1 = require('./routes/v1/index')
    const { Chat } = require('./chat')
    app.get("/",function (req, res) {
        res.status(200).send(`<h1>This is an API of Tracky - ASG team tracker </h1>`);
    });
    app.get("/ping",function (req, res) {
        infoDb.read()
        res.status(200).send({ success: 'true', title: infoDb.get("title").value(), message: infoDb.get("message").value(), "minRequiredAppVersion": minRequiredAppVersion});
    });
    app.use("/api/v1/room", routes_v1.rooms)
    
    //404
    app.use(function (req, res) {
        res.status(404).send({ success: 'false', code: 404, message: "Page not found! Bad API route!" });
    });
}


if(!httpsEnabled){
    if(!onlyApi && !onlyChat){
        // API 
        app.listen(process.env.PORT || apiPort, () => {
            console.log(`API running on port ${process.env.PORT || apiPort}`)

            // Start chat websocket
            chat(chatPort)
        });
    }
    else if(onlyApi){
        // API 
        app.listen(process.env.PORT || apiPort, () => {
            console.log(`API running on port ${process.env.PORT || apiPort}`)
        });
    }
    else if(onlyChat) chat(chatPort)
    
}
else{
    if(!onlyApi && !onlyChat){
        // API
        var credentials = {key: privateKey, cert: certificate};
        var httpsServer = https.createServer(credentials, app);
        httpsServer.listen(process.env.PORT || apiPort, () => {
            console.log(`API running on port ${process.env.PORT || apiPort} with HTTPS support`)
            
            // Start chat websocket
            chat(chatPort, {credentials: credentials})
        });  
    }  
    else if(onlyApi){
        // API
        var credentials = {key: privateKey, cert: certificate};
        var httpsServer = https.createServer(credentials, app);
        httpsServer.listen(process.env.PORT || apiPort, () => {
            console.log(`API running on port ${process.env.PORT || apiPort} with HTTPS support`)
        });  
    }
    else if(onlyChat){
        var credentials = {key: privateKey, cert: certificate};
        var httpsServer = https.createServer(credentials, app);
        // Start chat websocket
        chat(chatPort, {credentials: credentials})
    }
}
