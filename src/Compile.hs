module Compile (compile) where

import qualified Data.Map as Map

import qualified AST.Module as Module
import Elm.Utils ((|>))
import qualified Parse.Helpers as Parse
import qualified Parse.Parse as Parse
import qualified Reporting.Error as Error
import qualified Reporting.Task as Task
import qualified Reporting.Warning as Warning
import qualified Type.Inference as TI
import qualified Transform.Canonicalize as Canonical


compile
    :: String
    -> String
    -> Module.Interfaces
    -> String
    -> Task.Task Warning.Warning Error.Error Module.CanonicalModule

compile user projectName interfaces source =
  do
      -- determine if default imports should be added
      -- only elm-lang/core is exempt
      let needsDefaults =
            not (user == "elm-lang" && projectName == "core")

      -- Parse the source code
      validModule <-
          Task.mapError Error.Syntax $
            Parse.program needsDefaults (getOpTable interfaces) source

      -- Canonicalize all variables, pinning down where they came from.
      canonicalModule <-
          Canonical.module' interfaces validModule

      -- Run type inference on the program.
      types <-
          Task.from Error.Type $
            TI.infer interfaces canonicalModule

      -- Add the real list of tyes
      let body = (Module.body canonicalModule) { Module.types = types }

      return $ canonicalModule { Module.body = body }


getOpTable :: Module.Interfaces -> Parse.OpTable
getOpTable interfaces =
  Map.elems interfaces
    |> concatMap Module.iFixities
    |> map (\(assoc,lvl,op) -> (op,(lvl,assoc)))
    |> Map.fromList
