class_name GameState
extends RefCounted
## Carries choices across scene changes: the sector chosen on the sector page and the case chosen
## on the site map.

const DEFAULT_SECTOR_PATH := "res://content/construction/sector.json"

static var selected_sector_path := DEFAULT_SECTOR_PATH
static var selected_case_path := ""
