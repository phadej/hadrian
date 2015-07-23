module Settings.Util (
    -- Primitive settings elements
    arg, argPath, argM,
    argSetting, argSettingList,
    appendCcArgs,
    needBuilder
    -- argBuilderPath, argStagedBuilderPath,
    -- argPackageKey, argPackageDeps, argPackageDepKeys, argSrcDirs,
    -- argIncludeDirs, argDepIncludeDirs,
    -- argConcat, argConcatPath, argConcatSpace,
    -- argPairs, argPrefix, argPrefixPath,
    -- argPackageConstraints,
    ) where

import Util
import Builder
import Expression
import Oracles.Base
import Oracles.Setting
import Settings.User

-- A single argument.
arg :: String -> Args
arg = append . return

-- A single path argument. The path gets unified.
argPath :: String -> Args
argPath = append . return . unifyPath

argM :: Action String -> Args
argM = appendM . fmap return

argSetting :: Setting -> Args
argSetting = argM . setting

argSettingList :: SettingList -> Args
argSettingList = appendM . settingList

-- Pass arguments to Gcc and corresponding lists of sub-arguments of GhcCabal
appendCcArgs :: [String] -> Args
appendCcArgs xs = do
    stage <- asks getStage
    mconcat [ builder (Gcc stage) ? append xs
            , builder GhcCabal    ? appendSub "--configure-option=CFLAGS" xs
            , builder GhcCabal    ? appendSub "--gcc-options" xs ]

-- Make sure a builder exists on the given path and rebuild it if out of date.
-- If laxDependencies is true (Settings/User.hs) then we do not rebuild GHC
-- even if it is out of date (can save a lot of build time when changing GHC).
needBuilder :: Builder -> Action ()
needBuilder ghc @ (Ghc stage) = do
    path <- builderPath ghc
    if laxDependencies then orderOnly [path] else need [path]

needBuilder builder = do
    path <- builderPath builder
    need [path]



-- packageData :: Arity -> String -> Args
-- packageData arity key =
--     return $ EnvironmentParameter $ PackageData arity key Nothing Nothing

-- -- Accessing key value pairs from package-data.mk files
-- argPackageKey :: Args
-- argPackageKey = packageData Single "PACKAGE_KEY"

-- argPackageDeps :: Args
-- argPackageDeps = packageData Multiple "DEPS"

-- argPackageDepKeys :: Args
-- argPackageDepKeys = packageData Multiple "DEP_KEYS"

-- argSrcDirs :: Args
-- argSrcDirs = packageData Multiple "HS_SRC_DIRS"

-- argIncludeDirs :: Args
-- argIncludeDirs = packageData Multiple "INCLUDE_DIRS"

-- argDepIncludeDirs :: Args
-- argDepIncludeDirs = packageData Multiple "DEP_INCLUDE_DIRS_SINGLE_QUOTED"

-- argPackageConstraints :: Packages -> Args
-- argPackageConstraints = return . EnvironmentParameter . PackageConstraints

-- -- Concatenate arguments: arg1 ++ arg2 ++ ...
-- argConcat :: Args -> Args
-- argConcat = return . Fold Concat

-- -- </>-concatenate arguments: arg1 </> arg2 </> ...
-- argConcatPath :: Args -> Args
-- argConcatPath = return . Fold ConcatPath

-- -- Concatene arguments (space separated): arg1 ++ " " ++ arg2 ++ ...
-- argConcatSpace :: Args -> Args
-- argConcatSpace = return . Fold ConcatSpace

-- -- An ordered list of pairs of arguments: prefix |> arg1, prefix |> arg2, ...
-- argPairs :: String -> Args -> Args
-- argPairs prefix settings = settings >>= (arg prefix |>) . return

-- -- An ordered list of prefixed arguments: prefix ++ arg1, prefix ++ arg2, ...
-- argPrefix :: String -> Args -> Args
-- argPrefix prefix = fmap (Fold Concat . (arg prefix |>) . return)

-- -- An ordered list of prefixed arguments: prefix </> arg1, prefix </> arg2, ...
-- argPrefixPath :: String -> Args -> Args
-- argPrefixPath prefix = fmap (Fold ConcatPath . (arg prefix |>) . return)

-- TODO: do '-ticky' in all debug ways?
-- wayHcArgs :: Way -> Args
-- wayHcArgs (Way _ units) = args
--     [ if (Dynamic    `elem` units)
--       then args ["-fPIC", "-dynamic"]
--       else arg "-static"
--     , when (Threaded   `elem` units) $ arg "-optc-DTHREADED_RTS"
--     , when (Debug      `elem` units) $ arg "-optc-DDEBUG"
--     , when (Profiling  `elem` units) $ arg "-prof"
--     , when (Logging    `elem` units) $ arg "-eventlog"
--     , when (Parallel   `elem` units) $ arg "-parallel"
--     , when (GranSim    `elem` units) $ arg "-gransim"
--     , when (units == [Debug] || units == [Debug, Dynamic]) $
--       args ["-ticky", "-DTICKY_TICKY"] ]