const express = require('express')
const fs = require('fs')
const router = express.Router()

//#region Config variables
//var adminPassword = randomFromZeroToNine() + randomFromZeroToNine() + randomFromZeroToNine() + randomFromZeroToNine() //Generate 4 random numbers
var databaseName = "questions"

// Get data from config
var cfg = fs.readFileSync("./config.json")
cfg = JSON.parse(cfg)
//adminPassword = cfg.adminPassword
databaseName = cfg.databaseName
apiPort = cfg.apiPort
//#endregion

//#region db settings
const low = require('lowdb')
const FileSync = require('lowdb/adapters/FileSync') 
const { json } = require('body-parser')
const adapter = new FileSync(`${databaseName}.json`)
const db = low(adapter)
//#endregion

// *****************************
// *   API starts from there   *
// *****************************

db.defaults({ rooms: [] }).write() //default variables for database


// *****************************
// *          Rooms            *
// *****************************

router.get("/all", (req, res) => {
    db.read()

    // Check for expired rooms and players
    RemoveExpiredRoomsAndPlayers()

    var roomsWithExpireTime = []

    db.get("rooms").value().forEach(room => {
        roomsWithExpireTime.push({
            "id": room.id,
            "expiresAt": room.expiresAt,
            "name": room.name,
            "showEnemyTeam": room.showEnemyTeam,
            "expiresIn": ExpiresInHours(room.expiresAt),
            "teams": room.teams
        })
    });

    res.status(200).send({
        success: "true",
        message: "OK",
        rooms: roomsWithExpireTime
    })
})

// Create room
router.post("/create", (req, res) => {
    db.read();

    // Check for expired rooms and players
    RemoveExpiredRoomsAndPlayers()

    var rooms = db.get("rooms").value()
    var roomsCount = rooms.length;

    if(roomsCount > 0) var lastRoomId = rooms[roomsCount - 1].id;
    else var lastRoomId = 0

    // When to expire
    var expires = Date.now();
    expires = expires + (86400000 * 2)// add 48h in ms

    var expiresIn = ExpiresInHours(expires)

    if(db.get("rooms").push({
        "id": lastRoomId + 1,
        "name": req.body.roomName,
        "expiresAt": expires,
        "showEnemyTeam": req.body.showEnemyTeam,
        "teams": JSON.parse(req.body.teams)
    }).write()){
        return res.status(200).send({
            success: "true",
            message: "Created room with id " + (lastRoomId + 1),
            newRoomId: lastRoomId + 1,
            expiresIn: expiresIn
        })
    }
    else{
        return res.status(500).send({
            success: "false",
            message: "Error while creating room"
        })
    }
})

// Get room data
router.get('/:id', (req, res) => {
    db.read()

    const id = parseInt(req.params.id, 10);
    
    var list = db.get("rooms").value();
    var roomId = list.findIndex(room => room.id === id);

    if(roomId != -1){
        var room = db.get("rooms").get(roomId).value();

        return res.status(200).send({
            success: 'true',
            message: 'Room found',
            expiresIn: ExpiresInHours(room.expiresAt),
            roomId: room.id,
            teams: room.teams
        });
    }
    else{
        return res.status(404).send({
            success: 'false',
            message: 'Room not found. Wrong ID',
        });
    }
})

// Remove room
router.delete('/:id', (req, res) => {
    const id = parseInt(req.params.id, 10);

    if(RemoveRoom(id)){
        return res.status(200).send({
            success: 'true',
            message: 'Room found and deleted'
        });
    }
    else{
        return res.status(404).send({
            success: 'false',
            message: 'Room not found'
        });
    }
})

// *****************************
// *          Players          *
// *****************************

// Join player to team on room ID
router.post('/join/:id', (req, res) => {
    db.read();

    // Check for expired rooms and players
    RemoveExpiredRoomsAndPlayers()

    const id = parseInt(req.params.id, 10);
    
    var list = db.get("rooms").value();
    var roomId = list.findIndex(room => room.id === id);
    if(roomId != -1) var teamId = list[roomId].teams.findIndex(team => team.name === req.body.teamName)

    if(roomId != -1 && teamId != -1){
        // Check is name not taken
        var isNameTaken = false
        list[roomId].teams[teamId].players.forEach((player) => {
            if(player.name === req.body.playerName) isNameTaken = true
        })

        if(!isNameTaken){
            db.get("rooms").get(roomId).get("teams").get(teamId).get("players").push({
                "name": req.body.playerName,
                "lastSeen": Date.now(),
                "icon": req.body.icon,
                "latitude": "0",
                "longitude": "0"
            }).write()

            return res.status(200).send({
                success: 'true',
                message: `Player "${req.body.playerName}" joined to team: ${req.body.teamName}`
            });
        }
        else{
            return res.status(409).send({
                success: 'false',
                message: `Player with this name already exists in this team`
            });
        }        
    }
    else{
        return res.status(404).send({
            success: 'false',
            message: `Room or team not found`
        });
    }
})

// Update player location on room ID
router.post('/:id', (req, res) => {
    db.read();

    const id = parseInt(req.params.id, 10);
    
    var list = db.get("rooms").value();
    var success = false;
    var roomId = list.findIndex(room => room.id === id);
    if(roomId != -1) var teamId = list[roomId].teams.findIndex(team => team.name === req.body.teamName)

    if(roomId != -1 && teamId != -1){
        success = true;

        var playerIndex = list[roomId].teams[teamId].players.findIndex(player => player.name === req.body.playerName)

        if(playerIndex > -1){
            db.get("rooms").get(roomId).get("teams").get(teamId).get("players").get(playerIndex).set("latitude", req.body.latitude).set("longitude", req.body.longitude).set("lastSeen", Date.now()).write();
        }
        else{
            return res.status(404).send({
                success: 'false',
                message: 'Player not found in this team',
            });
        }
        
        
        return res.status(200).send({
            success: 'true',
            message: 'Room found, updating location and returning players',
            teams: db.get("rooms").get(roomId).get("teams").value()
        });
    }

    if(!success){
        return res.status(404).send({
            success: 'false',
            message: 'Room not found. Wrong ID',
        });
    }
})

// Remove player from team on room ID
router.post('/leave/:id', (req, res) => {
    db.read();

    const id = parseInt(req.params.id, 10);
    
    var list = db.get("rooms").value();
    var roomId = list.findIndex(room => room.id === id);
    if(roomId != -1) var teamId = list[roomId].teams.findIndex(team => team.name === req.body.teamName)

    if(roomId != -1 && teamId != -1){
        // Check is player with that name in team
        var isInTeam = false
        var playerToRemove;
        list[roomId].teams[teamId].players.forEach((player) => {
            if(player.name === req.body.playerName) {
                isInTeam = true
                playerToRemove = player;
            }
        })

        if(isInTeam){
            RemovePlayerFromTeam(roomId, teamId, playerToRemove);

            return res.status(200).send({
                success: 'true',
                message: `Player "${req.body.playerName}" removed from team: ${req.body.teamName}`
            });
        }
        else{
            return res.status(409).send({
                success: 'false',
                message: `Player with this name not found in this team`
            });
        }        
    }
    else{
        return res.status(404).send({
            success: 'false',
            message: `Room or team not found`
        });
    }
})


function ExpiresInHours(time){
    return ((time - Date.now()) / 1000 / 60 / 60).toPrecision(2)
}

function RemoveRoom(roomId){
    db.read();
    
    var list = db.get("rooms").value();
    var roomIndexToRemove = list.findIndex(room => room.id === roomId);
    
    if(roomIndexToRemove > -1){
        var roomToRemove = db.get("rooms").get(roomIndexToRemove).value();
        db.get("rooms").remove(roomToRemove).write()
        return true
    }
    else{
        return false
    }
}

function RemovePlayerFromTeam(roomId, teamId, player){
    db.read();

    db.get("rooms").get(roomId).get("teams").get(teamId).get("players").remove(player).write()
}

function RemoveExpiredRoomsAndPlayers(){
    db.read();

    var rooms = db.get("rooms").value()
    var roomsToRemove = []
    var playersToRemove = []

    rooms.forEach(room => {
        if(room.expiresAt < Date.now()) roomsToRemove.push(room)

        // Look for expired players
        room.teams.forEach(team => {
            team.players.forEach(player => {
                if((Date.now() - player.lastSeen) > 1000 * 60 * 5) playersToRemove.push({"player": player, "team": team, "room": room})
            })
        })
    });

    if(roomsToRemove.length > 0){
        roomsToRemove.forEach((room) => {
            db.get("rooms").remove(room).write()
        })
    }
    
    if(playersToRemove.length > 0){
        playersToRemove.forEach(obj => {
            var list = rooms
            var roomIndex = list.findIndex(room => room.id === obj.room.id);
            
            if(roomIndex > -1){
                var teamId = list[roomIndex].teams.findIndex(team => team.name === obj.team.name)

                if(teamId > -1){
                    RemovePlayerFromTeam(roomIndex, teamId, obj.player)
                }           
            }
        })
    }
}

module.exports = router