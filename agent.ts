// import { connect } from "@permaweb/aoconnect";

// const { result, results, message, spawn, monitor, unmonitor, dryrun } = connect(
//   {
//     MU_URL: "https://mu.ao-testnet.xyz",
//     CU_URL: "https://cu.ao-testnet.xyz",
//     GATEWAY_URL: "https://arweave.net",
//     MODE: "legacy"
//   }
// );
// // result()
// // process.exit(0)

import { readFileSync } from "node:fs";

import { message, createDataItemSigner } from "@permaweb/aoconnect";

const wallet = JSON.parse(
  readFileSync("./wallet.json").toString(),
);

// The only 2 mandatory parameters here are process and signer
await message({
  /*
    The arweave TxID of the process, this will become the "target".
    This is the process the message is ultimately sent to.
  */
  process: "drHuWPvnhCknt7ubyhv40Ad0fnb0adXodS5bXJfyays",
  
  // Tags that the process will use as input.
  tags: [
    { name: "Action", value: "Debug-Send-TokenOut-To-Pool" },
    // { name: "Action", value: "Execute-Strategy" },
    // { name: "Action", value: "Withdraw" },
    // { name: "Action", value: "Info" },
    // { name: "Token-Id", value: "0syT13r0s0tgPmIed95bJnuSqaD29HQNN8D3ElLSrsc" },
    // { name: "Token-Id", value: "s6jcB3ctSbiDNwR-paJgy5iOAhahXahLul8exSLHbGE" },
    // { name: "Quantity", value: "1" },
    // { name: "Transfer-All", value: "true" },
  ],
  // A signer function used to build the message "signature"
  signer: createDataItemSigner(wallet),
//   /*
//     The "data" portion of the message
//     If not specified a random string will be generated
//   */
//   data: "any data",
})
  .then(console.log)
  .catch(console.error);