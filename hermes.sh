#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

RESET='\033[0m'
BOLD='\033[1m'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
LIGHT_GREEN='\033[1;32m'

declare -A dotFiles
declare -A configFiles
declare -A projectLangFiles
declare -A frameworkFiles

info()    { echo -e "${MAGENTA}ℹ${RESET} $*"; }
success() { echo -e "${GREEN}✔${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "${RED}✘${RESET} $*"; }
section() { echo -e "\n${BOLD}${CYAN}== $* ==${RESET}"; }

normalize() {
    tr '[:upper:]' '[:lower:]' <<< "$1"
}

json_escape() {
    sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' -e 's/\r/\\r/g' -e 's/\n/\\n/g'
}

json_from_assoc() {
    local -n assoc="$1"
    local first=1
    echo "{"
    for key in "${!assoc[@]}"; do
        (( first )) || echo ","
        first=0
        printf '  "%s": "%s"' \
            "$(printf '%s' "$key" | json_escape)" \
            "$(printf '%s' "${assoc[$key]}" | json_escape)"
    done
    echo
    echo "}"
}

json_from_frameworks() {
    local first_file=1
    echo "{"
    for file in "${!frameworkFiles[@]}"; do
        (( first_file )) || echo ","
        first_file=0
        printf '  "%s": [' "$(printf '%s' "$file" | json_escape)"
        local first_url=1
        for url in ${frameworkFiles[$file]}; do
            (( first_url )) || echo ","
            first_url=0
            printf '"%s"' "$(printf '%s' "$url" | json_escape)"
        done
        echo -n "]"
    done
    echo
    echo "}"
}

declare -A FRAMEWORK_DOCS=(
    [react]="https://react.dev/learn"
    [vue]="https://vuejs.org/guide/"
    [angular]="https://angular.io/docs"
    [svelte]="https://svelte.dev/docs"
    [django]="https://docs.djangoproject.com/en/stable/"
    [flask]="https://flask.palletsprojects.com/"
    [rails]="https://guides.rubyonrails.org/"
    [laravel]="https://laravel.com/docs"
    [spring]="https://spring.io/projects/spring-framework"
    [express]="https://expressjs.com/en/4x/api.html"
    [nextjs]="https://nextjs.org/docs"
    [nuxt]="https://nuxt.com/docs/getting-started/introduction"
    [gatsby]="https://www.gatsbyjs.com/docs/"
    [tailwind]="https://tailwindcss.com/docs"
    [bootstrap]="https://getbootstrap.com/docs/5.0/getting-started/introduction/"
    [jquery]="https://api.jquery.com/"
    [tensorflow]="https://www.tensorflow.org/learn"
    [pytorch]="https://pytorch.org/docs/stable/index.html"
    [poetry]="https://python-poetry.org/docs/"
    [maven]="https://maven.apache.org/guides/index.html"
    [gradle]="https://docs.gradle.org/current/userguide/userguide.html"
    [cargo]="https://doc.rust-lang.org/cargo/"
    [go_modules]="https://blog.golang.org/using-go-modules"
    [composer]="https://getcomposer.org/doc/"
    [bundler]="https://bundler.io/docs.html"
    [flutter]="https://flutter.dev/docs"
    [react_native]="https://reactnative.dev/docs/getting-started"
    [ionic]="https://ionicframework.com/docs"
    [cordova]="https://cordova.apache.org/docs/en/latest/"
    [electron]="https://www.electronjs.org/docs/latest"
    [unity]="https://docs.unity3d.com/Manual/index.html"
    [unreal]="https://docs.unrealengine.com/en-US/index.html"
    [godot]="https://docs.godotengine.org/en/stable/"
    [wordpress]="https://developer.wordpress.org/"
    [drupal]="https://www.drupal.org/docs"
    [joomla]="https://docs.joomla.org/"
    [shopify]="https://shopify.dev/docs"
    [magento]="https://developer.adobe.com/commerce/docs/"
    [mongodb]="https://docs.mongodb.com/"
    [redis]="https://redis.io/documentation"
    [elasticsearch]="https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html"
    [rabbitmq]="https://www.rabbitmq.com/documentation.html"
    [kafka]="https://kafka.apache.org/documentation/"
    [prometheus]="https://prometheus.io/docs/introduction/overview/"
    [grafana]="https://grafana.com/docs/grafana/latest/"
    [jenkins]="https://www.jenkins.io/doc/"
    [bitbucket_pipelines]="https://support.atlassian.com/bitbucket-cloud/docs/get-started-with-bitbucket-pipelines/"
    [selenium]="https://www.selenium.dev/documentation/en/"
    [cypress]="https://docs.cypress.io/guides/overview/why-cypress"
    [jest]="https://jestjs.io/docs/getting-started"
    [mocha]="https://mochajs.org/#getting-started"
    [jasmine]="https://jasmine.github.io/pages/getting_started.html"
    [pytest]="https://docs.pytest.org/en/stable/"
    [unittest]="https://docs.python.org/3/library/unittest.html"
    [rspec]="https://rspec.info/documentation/"
    [capybara]="https://teamcapybara.github.io/capybara/"
    [selenium]="https://www.selenium.dev/documentation/en/"
    [cucumber]="https://cucumber.io/docs/guides/10-minute-tutorial/"
    [robot_framework]="https://robotframework.org/robotframework/latest/RobotFrameworkUserGuide.html"
)

print_entry() {
    local label="$1" file="$2" url="$3"
    if [[ -n "$url" ]]; then
        echo -e "  ${CYAN}${label}:${RESET} ${BOLD}$file${RESET}"
        echo -e "    ${GREEN}Docs:${RESET} $url"
    else
        warn "No known documentation for $file"
    fi
}

get_scrolls() {
    local TARGET_DIR="${1:-.}"
    local REQUESTED_ARRAY="${2:-}"

    REQUESTED_ARRAY="$(normalize "$REQUESTED_ARRAY")"

    dotFiles=()
    configFiles=()
    projectLangFiles=()
    frameworkFiles=()

    local -a project_dotfiles project_configfiles project_langfiles

    section "Scanning directory: $TARGET_DIR"

    mapfile -t project_dotfiles < <(
        find "$TARGET_DIR" -mindepth 1 -maxdepth 2 -type f -name ".*" ! -name "." ! -name ".."
    )

    mapfile -t project_configfiles < <(
        find "$TARGET_DIR" -mindepth 1 -maxdepth 2 -type f -iname "*config*"
    )

    mapfile -t project_langfiles < <(
        find "$TARGET_DIR" -mindepth 1 -maxdepth 2 -type f \( \
            -iname "*.py" -o -iname "*.js" -o -iname "*.sh" -o -iname "*.bash" \
            -o -iname "*.yaml" -o -iname "*.yml" -o -iname "*.ts" -o -iname "*.tsx" \
            -o -iname "*.jsx" -o -iname "*.go" -o -iname "*.rs" -o -iname "*.java" \
            -o -iname "*.cpp" -o -iname "*.c" -o -iname "*.css" -o -iname "*.html" \
            -o -iname "*.php" -o -iname "*.lua" -o -iname "*.rb" -o -iname "*.md" \
            -o -iname "*.json" -o -iname "*.xml" -o -iname "*.perl" -o -iname "*.pl" \
            -o -iname "*.swift" -o -iname "*.kt" -o -iname "*.scala" -o -iname "*.hs" \
            -o -iname "*.r" -o -iname "*.dart" -o -iname "*.elm" -o -iname "*.clj" \
            -o -iname "*.groovy" -o -iname "*.coffee" -o -iname "*.vb" -o -iname "*.fs" \
            -o -iname "*.scm" -o -iname "*.liquid" -o -iname "*.m" \
        \)
    )

    success "Dotfiles found: ${#project_dotfiles[@]}"
    success "Config files found: ${#project_configfiles[@]}"
    success "Language files found: ${#project_langfiles[@]}"

    section "Dotfiles"

    for path in "${project_dotfiles[@]}"; do
        file="$(basename "$path")"
        normalized_file="$(normalize "$file")"

        case "$normalized_file" in
            .gitignore)  dotFiles["$file"]="https://git-scm.com/docs/gitignore" ;;
            .env)        dotFiles["$file"]="https://12factor.net/config" ;;
            .bashrc)     dotFiles["$file"]="https://www.gnu.org/software/bash/manual/bash.html#Bash-Startup-Files" ;;
            .zshrc)      dotFiles["$file"]="https://zsh.sourceforge.io/Doc/Release/Files.html" ;;
            .vimrc)      dotFiles["$file"]="https://vimhelp.org/options.txt.html" ;;
            .tmux.conf)  dotFiles["$file"]="https://github.com/tmux/tmux/wiki" ;;
            .aliases)    dotFiles["$file"]="https://www.gnu.org/software/bash/manual/bash.html#Aliases" ;;
            *)           dotFiles["$file"]="https://www.google.com/search?q=${file}_documentation" ;;
        esac

        print_entry "Dotfile" "$file" "${dotFiles[$file]}"
    done

    section "Config Files & Frameworks"

    declare -A config_groups config_urls

    for path in "${project_configfiles[@]}"; do
        file="$(basename "$path")"
        normalized_file="$(normalize "$file")"

        case "$normalized_file" in
            package.json)      configFiles["$file"]="https://docs.npmjs.com/cli/v9/configuring-npm/package-json" ;;
            tsconfig.json)     configFiles["$file"]="https://www.typescriptlang.org/tsconfig" ;;
            webpack.config.js) configFiles["$file"]="https://webpack.js.org/concepts/configuration/" ;;
            .eslintrc*)        configFiles["$file"]="https://eslint.org/docs/latest/use/configure/" ;;
            .babelrc*)         configFiles["$file"]="https://babeljs.io/docs/en/configuration" ;;
            settings.y*ml)     configFiles["$file"]="https://yaml.org/spec/1.2/spec.html" ;;
            *)                 configFiles["$file"]="https://www.google.com/search?q=${file}_documentation" ;;
        esac

        # Group by normalized filename
        config_groups["$normalized_file"]+="$file "
        config_urls["$normalized_file"]="${configFiles[$file]}"

        IFS=' ._-' read -r -a parts <<< "$normalized_file"

        for part in "${parts[@]}"; do
            [[ -z "$part" ]] && continue
            if [[ -v "FRAMEWORK_DOCS[$part]" ]]; then
                frameworkFiles["$file"]+="${FRAMEWORK_DOCS[$part]} "
            fi
        done
    done

    # Display grouped config files
    for config_type in "${!config_groups[@]}"; do
        files="${config_groups[$config_type]}"
        url="${config_urls[$config_type]}"
        echo -e "  ${CYAN}${config_type}:${RESET} ${BOLD}${files}${RESET}"
        echo -e "    ${GREEN}Docs:${RESET} $url"
    done

    # Display frameworks separately if found
    if [[ ${#frameworkFiles[@]} -gt 0 ]]; then
        echo -e "  ${MAGENTA}Frameworks:${RESET}"
        for file in "${!frameworkFiles[@]}"; do
            printf "    ${BOLD}%s${RESET}: %s\n" "$file" "${frameworkFiles[$file]}"
        done
    fi

    section "Language Files"

    declare -A lang_groups lang_urls lang_names
    
    # First pass: group files by extension and collect metadata
    for path in "${project_langfiles[@]}"; do
        file="$(basename "$path")"
        normalized_file="$(normalize "$file")"
        ext="${normalized_file##*.}"

        lang_groups["$ext"]+="$file "

        # Determine language name and URL for this extension
        if [[ ! -v lang_urls["$ext"] ]]; then
            case "$ext" in
                py)    lang_names["$ext"]="Python"; lang_urls["$ext"]="https://docs.python.org/3/" ;;
                js)    lang_names["$ext"]="JavaScript"; lang_urls["$ext"]="https://developer.mozilla.org/docs/Web/JavaScript" ;;
                sh)    lang_names["$ext"]="Shell"; lang_urls["$ext"]="https://www.gnu.org/software/bash/manual/bash.html" ;;
                bash)  lang_names["$ext"]="Bash"; lang_urls["$ext"]="https://www.gnu.org/software/bash/manual/bash.html" ;;
                yml)   lang_names["$ext"]="YAML"; lang_urls["$ext"]="https://yaml.org/spec/" ;;
                yaml)  lang_names["$ext"]="YAML"; lang_urls["$ext"]="https://yaml.org/spec/" ;;
                ts)    lang_names["$ext"]="TypeScript"; lang_urls["$ext"]="https://www.typescriptlang.org/docs/" ;;
                tsx)   lang_names["$ext"]="TypeScript/React"; lang_urls["$ext"]="https://www.typescriptlang.org/docs/" ;;
                jsx)   lang_names["$ext"]="React/JSX"; lang_urls["$ext"]="https://react.dev/learn" ;;
                go)    lang_names["$ext"]="Go"; lang_urls["$ext"]="https://go.dev/doc/" ;;
                rs)    lang_names["$ext"]="Rust"; lang_urls["$ext"]="https://doc.rust-lang.org/book/" ;;
                java)  lang_names["$ext"]="Java"; lang_urls["$ext"]="https://docs.oracle.com/en/java/" ;;
                c)     lang_names["$ext"]="C"; lang_urls["$ext"]="https://en.cppreference.com/w/" ;;
                cpp)   lang_names["$ext"]="C++"; lang_urls["$ext"]="https://en.cppreference.com/w/" ;;
                css)   lang_names["$ext"]="CSS"; lang_urls["$ext"]="https://developer.mozilla.org/docs/Web/CSS" ;;
                html)  lang_names["$ext"]="HTML"; lang_urls["$ext"]="https://developer.mozilla.org/docs/Web/HTML" ;;
                php)   lang_names["$ext"]="PHP"; lang_urls["$ext"]="https://www.php.net/docs.php" ;;
                lua)   lang_names["$ext"]="Lua"; lang_urls["$ext"]="https://www.lua.org/docs.html" ;;
                rb)    lang_names["$ext"]="Ruby"; lang_urls["$ext"]="https://www.ruby-lang.org/en/documentation/" ;;
                md)    lang_names["$ext"]="Markdown"; lang_urls["$ext"]="https://www.markdownguide.org/basic-syntax/" ;;
                liquid) lang_names["$ext"]="Liquid"; lang_urls["$ext"]="https://shopify.github.io/liquid/" ;;
                json)  lang_names["$ext"]="JSON"; lang_urls["$ext"]="https://www.json.org/json-en.html" ;;
                xml)   lang_names["$ext"]="XML"; lang_urls["$ext"]="https://www.w3.org/XML/" ;;
                pl)    lang_names["$ext"]="Perl"; lang_urls["$ext"]="https://perldoc.perl.org/" ;;
                perl)  lang_names["$ext"]="Perl"; lang_urls["$ext"]="https://perldoc.perl.org/" ;;
                swift) lang_names["$ext"]="Swift"; lang_urls["$ext"]="https://swift.org/documentation/" ;;
                kt)    lang_names["$ext"]="Kotlin"; lang_urls["$ext"]="https://kotlinlang.org/docs/home.html" ;;
                scala) lang_names["$ext"]="Scala"; lang_urls["$ext"]="https://docs.scala-lang.org/" ;;
                hs)    lang_names["$ext"]="Haskell"; lang_urls["$ext"]="https://www.haskell.org/documentation/" ;;
                r)     lang_names["$ext"]="R"; lang_urls["$ext"]="https://cran.r-project.org/manuals.html" ;;
                dart)  lang_names["$ext"]="Dart"; lang_urls["$ext"]="https://dart.dev/guides" ;;
                elm)   lang_names["$ext"]="Elm"; lang_urls["$ext"]="https://guide.elm-lang.org/" ;;
                clj)   lang_names["$ext"]="Clojure"; lang_urls["$ext"]="https://clojure.org/reference/documentation" ;;
                groovy) lang_names["$ext"]="Groovy"; lang_urls["$ext"]="https://groovy-lang.org/documentation.html" ;;
                coffee) lang_names["$ext"]="CoffeeScript"; lang_urls["$ext"]="https://coffeescript.org/#documentation" ;;
                vb)    lang_names["$ext"]="Visual Basic"; lang_urls["$ext"]="https://docs.microsoft.com/en-us/dotnet/visual-basic/" ;;
                fs)    lang_names["$ext"]="F#"; lang_urls["$ext"]="https://docs.microsoft.com/en-us/dotnet/fsharp/" ;;
                scm)   lang_names["$ext"]="Scheme"; lang_urls["$ext"]="https://mitpress.mit.edu/books/introduction-scheme" ;;
                m)     lang_names["$ext"]="MATLAB"; lang_urls["$ext"]="https://www.mathworks.com/help/matlab/" ;;
                *)     lang_names["$ext"]="Unknown"; lang_urls["$ext"]="https://www.google.com/search?q=${ext}_documentation" ;;
            esac
        fi
    done

    # Display grouped language files
    for ext in "${!lang_groups[@]}"; do
        lang_name="${lang_names[$ext]}"
        url="${lang_urls[$ext]}"
        files="${lang_groups[$ext]}"
        
        echo -e "  ${CYAN}${lang_name}:${RESET} ${BOLD}${files}${RESET}"
        echo -e "    ${GREEN}Docs:${RESET} $url"
    done

    if [[ -n "$REQUESTED_ARRAY" ]]; then
        section "Requested keys: $REQUESTED_ARRAY"
        case "$REQUESTED_ARRAY" in
            dotfiles)         printf "%s\n" "${!dotFiles[@]}" ;;
            configfiles)      printf "%s\n" "${!configFiles[@]}" ;;
            projectlangfiles) printf "%s\n" "${!projectLangFiles[@]}" ;;
            frameworkfiles)   printf "%s\n" "${!frameworkFiles[@]}" ;;
            *) warn "Unknown array requested" ;;
        esac
    fi

    if [[ -n "${SAVE_SCROLLS:-}" ]]; then
        {
            echo "{"
            printf '  "directory": "%s",\n' "$(printf '%s' "$TARGET_DIR" | json_escape)"
            echo '  "dotfiles":'
            json_from_assoc dotFiles | sed 's/^/  /'
            echo ","
            echo '  "config_files":'
            json_from_assoc configFiles | sed 's/^/  /'
            echo ","
            echo '  "language_files":'
            json_from_assoc projectLangFiles | sed 's/^/  /'
            echo ","
            echo '  "frameworks":'
            json_from_frameworks | sed 's/^/  /'
            echo "}"
        } > "$SAVE_SCROLLS"
        success "Scrolls saved to $SAVE_SCROLLS"
    fi
}

COMMAND=""
ARRAY_REQUEST=""
SAVE_SCROLLS=""
TARGET_DIRS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -get_scrolls)
            COMMAND="get_scrolls"
            shift
            while [[ $# -gt 0 && "$1" != -* ]]; do
                TARGET_DIRS+=("$1")
                shift
            done
            ;;
        --save_scrolls)
            SAVE_SCROLLS="$2"
            shift 2
            ;;
        --l|--list)
            ARRAY_REQUEST="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: ./hermes -get_scrolls DIR [DIR ...] [--save_scrolls FILE] [--l ARRAY]"
            exit 0
            ;;
        *)
            error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

case "$COMMAND" in
    get_scrolls)
        [[ ${#TARGET_DIRS[@]} -eq 0 ]] && TARGET_DIRS=(.)
        for dir in "${TARGET_DIRS[@]}"; do
            get_scrolls "$dir" "$ARRAY_REQUEST"
        done
        ;;
    save_scrolls)
        error "--save_scrolls must be used with -get_scrolls"
        exit 1
        ;;
    list)
        error "--l|--list must be used with -get_scrolls"
        exit 1
        ;;
    *)
        error "No command specified"
        exit 1
        ;;
esac
