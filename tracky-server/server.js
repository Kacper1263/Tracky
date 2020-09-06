//Check are required packages installed
try {
    require('express')
    require('body-parser')
    require('fs')
    require('path')
    require('lowdb')
    require('readline-sync')
} catch (e) {
    return console.log(`\n   You don't have required packages! \n\n   Use "npm i" to install them! \n\n`)
}

const express = require('express')
const bodyParser = require('body-parser')
const fs = require('fs')
const readline = require('readline-sync')

//#region Config variables
// var adminPassword = randomFromZeroToNine() + randomFromZeroToNine() + randomFromZeroToNine() + randomFromZeroToNine() //Generate 4 random numbers
var databaseName = "rooms"
var apiPort = 5000;
//#endregion

//#region Get data from config
try {
    var cfg = fs.readFileSync("./config.json")
    cfg = JSON.parse(cfg)
    //adminPassword = cfg.adminPassword
    databaseName = cfg.databaseName
    apiPort = cfg.apiPort
} catch (e) {
    //Create config if not exist
    if (!fs.existsSync("./config.json")) {
        var data = {
            //adminPassword: adminPassword,
            databaseName: databaseName,
            apiPort: apiPort,
        }
        data = JSON.stringify(data, null, 2)
        fs.writeFileSync("./config.json", data)
        console.log("Config file created, you can now edit it")
        return readline.keyInPause("\nProgram ended...")
    } else {
        console.log("Error occurred: " + e + "\n\nYou can try to delete config file")
        return readline.keyInPause("\nProgram ended...")
    }
}
//#endregion

// Check is password set
if(!databaseName || !apiPort) return console.log("You must set databaseName and apiPort in config.json!") 


const low = require('lowdb')
const FileSync = require('lowdb/adapters/FileSync')
const adapter = new FileSync(`${databaseName}.json`)
const db = low(adapter)

// *****************************
// *   API starts from there   *
// *****************************

db.defaults({ rooms: [] }).write() //default variables for database

// Set up the express app
const app = express();
app.use(bodyParser.json({limit: '50mb'}));
app.use(bodyParser.urlencoded({limit: '50mb', extended: true}));

//Routes API v1
var routes_v1 = require('./routes/v1/index')
app.get("/",function (req, res) {
    res.status(200).send(`<h1>This is an API of Tracky - ASG team tracker </h1>`);
});
app.use("/api/v1/room", routes_v1.rooms)

//404
app.use(function (req, res) {
    res.status(404).send({ success: 'false', code: 404, message: "Page not found! Bad API route!" });
});


app.listen(process.env.PORT || apiPort, () => {
    console.log(`API running on port ${process.env.PORT || apiPort}`)
});
