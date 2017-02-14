import os
import argparse
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(description='Include creator for GoD-Tony\'s updater plugin.')
    parser.add_argument("--include_dir", type=Path, help='The path where to drop the include')
    parser.add_argument("--url", type=str, help="The url where the updater file is located")
    args = parser.parse_args()
    include_dir = args.include_dir.resolve()
    url = args.url
    template = """#if defined _updater_helper_included
 #endinput
#endif
#define _updater_helper_included
#define UPDATER_HELPER_URL "{}" """
    file_content = template.format(url)
    with open(str(include_dir.joinpath("updater_helpers.inc")), "w") as file:
        file.write(file_content)
    
if __name__=="__main__": main()