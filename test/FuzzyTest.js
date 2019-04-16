
const { exec,spawnSync,spawn } = require("child_process");
const fs = require("fs");
//a function to delay s seconds
const delay = s => new Promise(res => setTimeout(res, s*1000));
let dataFiles = [];
let fuzzyDataPath = "./test/fuzzy";
let folder = fs.readdirSync(fuzzyDataPath);
folder.forEach(element => {
    if (element.startsWith("series_4")){
        let sub = fs.readdirSync(fuzzyDataPath+"/"+element);
        sub.forEach(subElement=>{
            if (subElement.endsWith(".json")){
                dataFiles.push(fuzzyDataPath+"/"+element+"/"+subElement);
            }
        });
    }
});
dataFiles.forEach(element=>{
    let unit = spawn("truffle", ["test","./test/FuzzyTestUnit.js",element]);
    unit.stdout.on("data",data=>{
        // console.log("----stdout start----");
        // console.log("stdout with:"+element);
        // console.log(""+data);
        process.stdout.write(".");
        let str = ""+data;
        if (str.indexOf("assert error")>-1 || str.indexOf("Error:")>-1){
            console.log("\nassert error with:"+element);
            console.log(str);
        }
        // console.log("---- stdout end ----");
    });
    unit.stderr.on("data",data=>{
        console.log("----stderr start----");
        console.log("stderr with:"+element);
        console.log(""+data);
        console.log("---- stderr end ----");
    });
    unit.on("error",error=>{
        console.log("----error start----");
        console.log("error with:"+element);
        console.log(""+error);
        console.log("---- error end ----");
    });
    unit.on("close",code=>{
        // console.log("----close start----");
        console.log("exit code:"+code+" close with:"+element);
        // console.log("---- close end ----");
    })
});
