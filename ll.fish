# The tags DB file must be located in ~/.file-tags-db
# The format of the file is like:
#
# /path/to/tagged/file tag1 tag2 tag3
# /path/to/another/file tag1
# 
function ll
    set db_file ~/.file-tags-db
    
    if test -f $db_file
        # We load the filenames and their tags from the DB
        # It results in a string in the form:
        # /path/to/dir/or/file:tag1;tag2,/path/to/another/file:tag1;tag2;tag3
        set tagged_files (awk 'NF>1 {
                                 printf("%s", $1 ":")
                                 for (i = 2; i <= NF; i++) {
                                     printf("%s", $i)
                                     if (i < NF) {
                                         printf(";")
                                     }
                                 }
                                 printf(",")
                              }' < $db_file | sed 's/,$//g')
    else
        set tagged_files ""
    end
    # If the DB contains no tags at all then we won't put
    # the option in the command line
    if test $tagged_files != ""
        set tagged_files_arg -v tagged_files_in=$tagged_files
    end

    # We save the base dir path to the file(s) to be listed
    # If no path was supplied then we use the CWD
    if test (count $argv) -gt 0
        if test -d $argv[-1]
            set path (realpath $argv[-1])
        else
            set path (realpath (dirname $argv[-1]))
        end
    else
        set path (realpath .)
    end
    
    # We search for git repositories in the listed dir so
    # we can put a tag indicating it
    set files (ls $path)
    for file in $files
        if test -d $path/$file; and test -d $path/$file/.git
            set git_repos $path/$file $git_repos
        end
    end
    # If no repos are found then we won't put the option on
    # the command line
    if test (count $git_repos) -gt 0
        # We build a string in the form:
        # /path/to/repo1,/path/to/repo2
        set comma_sep_repos (echo -n $git_repos | sed 's/ /,/g')
        set git_repos_arg -v git_repos_in=$comma_sep_repos
    end
    
    ls -Alh --color=auto $argv | \
        awk $tagged_files_arg \
            $git_repos_arg \
            -v path=$path \
            'function printc(text, color) {
                printf("\x1b[%dm%s\x1b[0m", color, text)
            }
            
            BEGIN {
                # we create a hashmap in the form (path, tags)
                split(tagged_files_in, tmp, ",")
                for (i in tmp) {
                    split(tmp[i], pair, ":")
                    split(pair[2], tags, ";")
                    for (i in tags) {
                        tagged_files[pair[1]][i] = tags[i]
                    }
                }
                # We add the git tag to the directories being repositories
                split(git_repos_in, tmp, ",")
                for (i in tmp) {
                    if (tmp[i] in tagged_files) {
                        len = length(tagged_files[tmp[i]])
                        tagged_files[tmp[i]][len + 1] = "git"
                    } else {
                        tagged_files[tmp[i]][1] = "git"
                    }
                }
            }
            
            NR>1 {
                printf("%s", $0)
                file_path = path "/" $9
                # Actual printing of the tags
                if (file_path in tagged_files) {
                    printf(" [")
                    for (i in tagged_files[file_path]) {
                        if (i != 1) {
                            printf(",")
                        }
                        tag = tagged_files[file_path][i]
                        if (tag == "git") {
                            printc("git", 34)
                        } else {
                            printc(tagged_files[file_path][i], 31)
                        }
                    }
                    printf("]")
                }
                printf("\n")
            }' | column -t # Pretty print the output
end

