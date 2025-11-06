open! Core

let () = Command_unix.run Messaging.Cli.message_processor
