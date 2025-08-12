import Pkg
Pkg.activate(".")
Pkg.instantiate()
Pkg.add("StringEncodings")
Pkg.add("YAML")

using Dates
using Markdown
using Printf
using StringEncodings
using YAML

const DIR_BASE_REPO = "https://github.com/clareLab/lang-tutorial/tree/main"

const DIR_BASE_DOWNLOAD = "https://download-directory.github.io/?url="

const DIR_BASE = "/lang-tutorial"
const DIR_SRC = "src"
const DIR_DOCS = "docs"

function name_clean(text::AbstractString)::String
    return replace(String(text), "_" => " ")
end

function file_extension_get(f::String)::String
    ext = lowercase(splitext(basename(f))[2])
    return startswith(ext, ".") ? ext[2:end] : ext
end

function dir_item_count(dir::String)::String
    n = length(readdir(dir))
    if n == 0
        return nothing
    elseif n == 1
        return "$n item"
    else
        return "$n items"
    end
end

function size_directory_get(path::AbstractString)::Int
    total = 0
    for (root, _, files) in walkdir(path)
        for file in files
            path_file = joinpath(root, file)
            try
                total += stat(path_file).size
            catch
                println("[WARN] Skipping file: $file_path")
            end
        end
    end
    return total
end

function size_human_readable(size::Integer)::String
    if size < 1024
        return "$size Byte"
    elseif size < 1024^2
        return @sprintf("%d KiB", size / 1024)
    elseif size < 1024^3
        return @sprintf("%d MiB", size / 1024^2)
    else
        return @sprintf("%d GiB", size / 1024^3)
    end
end

function file_preview_generate(file_src::String)::String
    ext = lowercase(file_extension_get(file_src))
    file_src_full = joinpath(DIR_BASE, file_src)

    try
        bytes = read(file_src)
        content = try
            String(bytes)
        catch
            String(bytes, enc"Windows-1252")
        end

        if any(c -> c < ' ' && c != '\n' && c != '\t', content)
            return ""
        end

        # escaped = replace(content, r"&" => "&amp;", r"<" => "&lt;", r">" => "&gt;")
        return "```$(ext)\n" * content * "\n```"
    catch
        return ""
    end
end

function nested_pages_generate(dir_src::String, dir_docs::String, course_info)
    mkpath(dir_docs)
    is_dir = isdir(dir_src)

    if is_dir
        entries = readdir(dir_src)
        dirs = filter(name -> isdir(joinpath(dir_src, name)), entries)
        files = filter(name -> isfile(joinpath(dir_src, name)), entries)
    end

    dir_course = joinpath(DIR_SRC, course_info_whole(course_info))
    is_root_course = dir_src == dir_course

    course_info_id = course_info.id
    course_info_moodle = course_info.moodle
    course_info_prof = name_prettify(course_info.prof)
    course_info_name = name_clean(course_info.name)

    file_docs = joinpath(dir_docs, "index.md")
    file_origin = joinpath(DIR_BASE_REPO, dir_src)

    # Generate basic info about the page
    open(file_docs, "w") do f
        if is_root_course
            println(f, "# ", course_info_name, "\n")
            println(f, "<small>[← Back](../index.md)</small>", "\n")
            println(f, "## Basic Info", "\n")
            println(f, "- **Course ID:** ", course_info_id)
            println(f, "- **Professor:** ", course_info_prof)
            println(f, "- **[Moodle]($DIR_BASE_MOODLE$course_info_moodle)**", "\n")
            println(f, "- **<a href=\"$DIR_BASE_DOWNLOAD$file_origin\" download>Download</a>**")

            println(f, "\n")
            println(f, directory_table_generate(dir_src))

            # Prepare for copying Readme
            println(f, "\n")
        elseif is_dir
            println(f, "# ", name_clean(basename(dir_src)), "\n")
            println(f, "<small>[← Back](../index.md)</small>", "\n")
            println(f, "## Basic Info", "\n")
            println(f, "- **Item:** ", dir_item_count(dir_src))
            println(f, "- **Size:**  ", size_human_readable(size_directory_get(dir_src)))
            println(f, "- **[Origin]($file_origin)**", "\n")
            println(f, "- **<a href=\"$DIR_BASE_DOWNLOAD$file_origin\" download>Download</a>**")

            println(f, "\n")
            println(f, directory_tree_generate(dir_src, dir_course, name_clean(course_info.name)))
            println(f, "\n")
            println(f, directory_table_generate(dir_src))

            # Prepare for copying Readme
            println(f, "\n")
        else
            println(f, "# ", name_clean(splitext(basename(dir_src))[1]), "\n")
            println(f, "<small>[← Back](../index.md)</small>", "\n")
            println(f, "## Basic Info", "\n")
            println(f, "- **Type:    **", file_extension_get(dir_src))
            println(f, "- **Size:    **", size_human_readable(stat(dir_src).size))
            println(f, "- **[Origin]($file_origin)**", "\n")

            link_download = joinpath(DIR_BASE, dir_src)
            println(f, "- **<a href=\"$link_download\" download>Download</a>**")

            println(f, "\n")
            println(f, directory_tree_generate(dir_src, dir_course, name_clean(course_info.name)))
            println(f, "\n---\n")
            if lowercase(file_extension_get(dir_src)) == "md"
                println(f, "## More Info", "\n")
                println(f, read(dir_src, String))
            else
                println(f, "## Preview", "\n")
                println(f, file_preview_generate(dir_src))
            end
        end
    end

    if is_dir
        # Copy Readme
        readme_to_index_copy(dir_src, dir_docs)

        # Recursive
        for d in dirs
            nested_pages_generate(
                joinpath(dir_src, d),
                joinpath(dir_docs, d),
                course_info
            )
        end

        # I don't know why here I seperate dirs and files, but just in case
        for f in files
            nested_pages_generate(
                joinpath(dir_src, f),
                joinpath(dir_docs, f),
                course_info
            )
        end
    end
end

# Generate pages
function course_page_generate(dir_course::String)
    course_info = course_info_extract(basename(dir_course))
    if course_info === nothing
        println("[WARN] Skipping unrecognized directory: $dir_course")
        return
    end
    dir_docs = joinpath(DIR_DOCS_COURSES, basename(dir_course))
    nested_pages_generate(dir_course, dir_docs, course_info)
end

function nested_nav_build(path::String)
    entries = readdir(path; join=true, sort=true)
    nav = Vector{Any}()

    for entry in entries
        if isdir(entry)
            name = name_clean(basename(String(entry)))
            rel = joinpath("courses", relpath(entry, DIR_DOCS_COURSES))
            index_path = joinpath(rel, "index.md")
            children = nested_nav_build(entry)
            push!(nav, Dict("$name" => vcat([index_path], children)))
        end
    end

    return nav
end

function update_mkdocs_nav()
    mkdocs_path = "mkdocs.yml"
    backup_path = mkdocs_path * ".bak"
    cp(mkdocs_path, backup_path; force=true)

    original_lines = readlines(backup_path)
    new_lines = String[]

    in_nav = false
    skipping_courses = false

    for line in original_lines
        stripped = strip(line)

        if stripped == "nav:"
            in_nav = true
            push!(new_lines, "nav:")
            continue
        end

        if in_nav && startswith(stripped, "- Courses:")
            skipping_courses = true
            continue
        elseif in_nav && startswith(stripped, "- ")
            in_nav = false
            skipping_courses = false
        end

        if !skipping_courses
            push!(new_lines, line)
        end
    end

    nested_courses = Any["courses/index.md"]

    entries = readdir(DIR_DOCS_COURSES; join=true, sort=true)
    nav = Vector{Any}()
    for entry in entries
        if isdir(entry)
            course_base = basename(String(entry))
            course_name = name_clean(course_info_extract(course_base).name)
            rel = joinpath("courses", relpath(entry, DIR_DOCS_COURSES))
            index_path = joinpath(rel, "index.md")
            children = nested_nav_build(entry)
            push!(nav, Dict("$course_name" => vcat([index_path], children)))
        end
    end

    append!(nested_courses, nav)
    courses_entry = Dict("Courses" => nested_courses)

    nav_yaml_lines = split(YAML.write([courses_entry]), "\n")
    for line in nav_yaml_lines
        if !isempty(strip(line))
            push!(new_lines, "  " * line)
        end
    end

    open(mkdocs_path, "w") do f
        write(f, join(new_lines, "\n"))
    end
end