# DexOnline JSON API

This a quick and dirty JSON API built around data provided by [dexonline](https://dexonline.ro).

## What? Why?

I’m currently learning Romanian, and in so doing have stumbled across [dexonline](https://dexonline.ro): a free-to-use, [open-source](https://github.com/dexonline/dexonline) Romanian language dictionary which has gone a long way to filling in some of the gaps left by Duolingo 🙃

To fill in some of the other gaps, and somewhat inspired by my friend [Robb](https://robbowen.digital/), I set about building myself a little game to help me learn verb, noun, and adjective forms. While I _could_ have manually entered everything by hand, I thought I’d use Dex’s JSON API to pull stuff across as I needed it…  
… except the information I need [is missing from the API](https://github.com/dexonline/dexonline/issues/969), and while I did take a look at adding the functionality myself (open source is 💜), it’s been a _very_ long time since I wrote PHP in anger. DexOnline [exports its dataset for use](https://wiki.dexonline.ro/wiki/Protocol_de_exportare_a_datelor_v5), and I figured it couldn’t be _too_ hard to wrap a JSON API around it, right?

Right now I’m only running this internally, so this repo is more for folks’ idle curiousity, but I _might_ get around to putting it somewhere public sometime…

## Technical information

This tool is written in [Ruby](https://www.ruby-lang.org/en/) (3.2+), and uses a mySQL (or compatible) database for its backend. I’m running it under macOS for development and Debian for internal production use, but it should work wherever you can get Ruby working.

### Setup

You will need:

* Ruby (I’m using [rbenv](https://github.com/rbenv/rbenv))
* mySQL (or MariaDB)
* [watchexec](https://github.com/watchexec/watchexec)

To get started:

1. clone this repo
2. run `bundle`  
(note: if you’re running macOS + have [brew](https://brew.sh/) installed, you can run `make setup` instead)
3. copy `.env.example` to `.env` and customise `DATABASE_URL` to suit your environment
3. run `rake db:migrate` to set the database up
4. run `rake dex:update` to download the latest data from dexonline  
(this may take some time: you might want to make some tea or coffee…)
5. finally run `make run` to start the app

Once you’re set up, you can check for- and download further updates by running `rake dex:update` at any time.

### API docs

The API is deliberately fairly basic:

#### `/v1/search{keyword}`

Performs a lexeme search for the given keyword, returning the entry records for those that match.

Note that—as with dexonline’s site search—this doesn’t search inflected forms (so `/v1/search/copiii` will return zero results). If you wish to search inflected forms, add `?full` to the URL:

```
	/v1/search/copiii         # no resutls
	/v1/search/copiii?full    # returns entry for ‘copil (persoană)’
```

#### `/v1/search/{categorie}/{keyword}`

Performs a lexeme search as above, but restricts results by word type (that is: verb, noun, adjective, etc). Inflections are not searched by default, but can be searched by adding `?full` as above.

**Permitted values of `categorie`**

* `adjectiv`
* `forma_unica`
* `invariabil`
* `pronume`
* `substantiv_propriu`
* `substantiv`
* `verb`

#### `/v1/entry/{id}`

Returns a dictionary entry by ID, including definitions and linked lexemes.

```
	/v1/entry/20704 # returns entry for ‘a fi’ (v., to be)
```

Definition text will be partly formatted—see formatting notes below.

#### `/v1/source/{id}`

Returns information source data by ID. Sources are linked from definitions.


#### `/v1/lexem/{id}`

Returns a lexeme by ID, including all inflected versions.

```
	/v1/lexem/43175 # returns lexeme data for ‘pisică’ (s.f., cat)
```

## Caveats / What this is not

This project is _not_ supposed to be any kind of replacement for dexonline, neither is it intended to be authoritative. While it attempts to import the data provided and present it in a sensible way, I accept no responsibility if it doesn’t—please check with the source before doing anything hasty ;)

### Note on entry definitions

Entry definitions have been included in this project for completeness’ sake, but are not really related to anything I intend to use it for. As such, they’re a little bit janky in how they work and probably shouldn’t be relied upon. Notably, the definition data in dexonline’s exports is provided in a custom, marked-up format which this project does its best to convert into standard HTML where possible.  

That said, its doing so differs from dex—known differences are the treatment of spaced text, quoted text, and presentation of newlines; the last of which is only slightly because I can’t work out how dex’s formatting code actually achieves this (:

### Note on emphasis marking

Dexonline rather usefully marks emphasis in words using underlines, and this is carried over into this project via judicious use of [Unicode combining diacritical marks](https://unicode-explorer.com/b/0300), notably [U+0332](https://unicode-explorer.com/c/0332) and [U+0333](https://unicode-explorer.com/c/0332). I may yet regret this, but for now I think it’s pretty cool…

---

Share and enjoy :)
