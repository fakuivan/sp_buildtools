import vdf
import os
import argparse
from pathlib import Path, PurePosixPath

class RemoteToPathFormatter:
    def __init__(self, local_root, remote_root):
        """
        local_root       This Path or string should be replaced by your local root directory.
        remote_root      This PurePosixPath or string should be put instead of the local root.
        """
        self.local_root = Path(local_root)
        self.remote_root = PurePosixPath(remote_root)
    def format(self, local_directory):
        """
        local_directory  This directory will have it's local root folder swapped by the remote one.
        """
        return self.remote_root.joinpath(PurePosixPath(Path(local_directory).relative_to(self.local_root)))
    
    def strip_local(self, local_directory):
        """
        local_directory The directory to strip
        """
        return Path(local_directory).relative_to(self.local_root)

def main():
    parser = argparse.ArgumentParser(description='Creates an update script for GoD-Tony\'s sourcemod plugin updater.')
    parser.add_argument("--sm_path", type=Path, help="The path to the root sourcemod folder that you bundle with your plugin")
    parser.add_argument("--version", type=str, help="The current version of the plugin")
    parser.add_argument("--mod_path", type=Path, help="The path to the mod root folder", nargs="?")
    parser.add_argument("--notes", type=str, help="Notes to add to the update scirpt, usually a brief changelog", nargs="+")
    parser.add_argument("--output", type=Path, help="Output file")
    args = parser.parse_args()
    sm_path = args.sm_path
    script = god_tony_update_script(Path(args.sm_path), args.mod_path, list(args.notes), str(args.version))
    with open(str(args.output), "w") as fp:
        vdf.dump(script.build_vdf(), fp, pretty = True)

class god_tony_update_script:
    type_map_SM = {"scripting" : "Source", 
                   None        : "Plugin"}

    type_map_MOD = {None       : "Plugin"}

    def __init__(self, sm_path, mod_path, notes, version):
        self.sm_formatter = RemoteToPathFormatter(sm_path, "Path_SM")
        if mod_path != None:
            self.mod_formatter = RemoteToPathFormatter(mod_path, "Path_Mod")
        else:
            self.mod_formatter = None
        self.version = str(version)
        self.notes = list()
        for note in list(notes): 
            self.notes += [str(note)]
        self.get_files()
    
    def get_files(self):
        self.files = vdf.VDFDict()
        for root, dirs, files in os.walk(str(self.sm_formatter.local_root), topdown=True):
            root = Path(root)
            for file in files:
                file = root.joinpath(file)
                self.sm_formatter.format(file)
                remote = self.sm_formatter.format(file)
                root_file_folder = self.sm_formatter.strip_local(file).parts[0]
                _type = self.type_map_SM.get(root_file_folder, self.type_map_SM[None])
                self.files[_type] = str(remote)
        
        if self.mod_formatter is not None:
            for root, dirs, files in os.walk(str(self.mod_formatter.local_root), topdown=True):
                root = Path(root)
                for file in files:
                    file = root.joinpath(file)
                    self.mod_formatter.format(file)
                    remote = self.mod_formatter.format(file)
                    file_path_parts = self.mod_formatter.strip_local(file).parts
                    root_file_folder = file_path_parts[0]
                    if root_file_folder != "addons" and file_path_parts.get(1) != "sourcemod":  #skip the sm folder
                        _type = self.type_map_MOD.get(root_file_folder, self.type_map_MOD[None])
                        self.files[_type] = str(remote)

    def build_vdf(self):
        root = vdf.VDFDict()
        root["Updater"] = vdf.VDFDict({"Information" : vdf.VDFDict({
                                           "Version" : vdf.VDFDict({
                                               "Latest" : str(self.version)})}), 
                                       "Files" : self.files})
        for note in self.notes:
            root["Updater"]["Information"]["Notes"] = note
        return root
        

if __name__ == "__main__": main()
