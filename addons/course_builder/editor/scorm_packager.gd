class_name IDScormPackager
extends RefCounted

## Builds a SCORM 1.2 zip from a Godot Web export folder. Editor-only; never runs on Play.
## See: editor/course_viewer.gd, resources/lms_settings.gd

const _MANIFEST_NAME := "imsmanifest.xml"
const _LAUNCH := "index.html"


func package_export(course: IDCourseData, export_dir: String, zip_path: String) -> String:
	if course == null or course.lms == null:
		return "Load a course with LMS settings first."
	var lms := course.lms
	if not lms.is_tracking_enabled():
		return "LMS preset is Off. Publishing is disabled."
	if not IDLmsSettings.is_safe_id(lms.identifier):
		return "Set a legal LMS Identifier before publishing."
	var root := export_dir.strip_edges().simplify_path()
	if root.is_empty() or not DirAccess.dir_exists_absolute(root):
		return "Choose a Web export folder."
	if not FileAccess.file_exists(root.path_join(_LAUNCH)):
		return "That folder has no index.html. Export Web first (Project → Export → Web)."
	var zip := zip_path.strip_edges().simplify_path()
	if zip.is_empty() or not zip.get_extension().to_lower() == "zip":
		return "Choose a .zip save path."
	var zip_dir := zip.get_base_dir()
	if not zip_dir.is_empty() and not DirAccess.dir_exists_absolute(zip_dir):
		return "Zip folder does not exist: %s" % zip_dir
	var files := _list_files(root)
	if files.is_empty():
		return "Export folder is empty."
	var manifest := _build_manifest(course, files)
	var manifest_path := root.path_join(_MANIFEST_NAME)
	var writer := FileAccess.open(manifest_path, FileAccess.WRITE)
	if writer == null:
		return "Could not write %s." % manifest_path
	writer.store_string(manifest)
	writer.close()
	if not files.has(_MANIFEST_NAME):
		files.append(_MANIFEST_NAME)
	var pack_err := _write_zip(root, files, zip)
	if pack_err != OK:
		return "Could not write zip (error %d)." % pack_err
	return ""


func _list_files(root: String) -> PackedStringArray:
	var found: PackedStringArray = []
	_walk(root, "", found)
	found.sort()
	return found


func _walk(root: String, rel: String, found: PackedStringArray) -> void:
	var dir_path := root if rel.is_empty() else root.path_join(rel)
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var child_rel := name if rel.is_empty() else rel.path_join(name)
		if dir.current_is_dir():
			_walk(root, child_rel, found)
		elif child_rel.get_extension().to_lower() != "zip":
			found.append(child_rel.replace("\\", "/"))
		name = dir.get_next()
	dir.list_dir_end()


func _write_zip(root: String, files: PackedStringArray, zip_path: String) -> Error:
	var zip_abs := zip_path.replace("\\", "/")
	var zipper := ZIPPacker.new()
	var err := zipper.open(zip_path)
	if err != OK:
		return err
	for rel in files:
		var rel_slash := str(rel).replace("\\", "/")
		var abs_path := root.path_join(rel_slash).replace("\\", "/")
		if abs_path == zip_abs:
			continue
		if rel_slash.get_extension().to_lower() == "zip":
			continue
		if not FileAccess.file_exists(root.path_join(rel)):
			continue
		var bytes := FileAccess.get_file_as_bytes(root.path_join(rel))
		err = zipper.start_file(rel_slash)
		if err != OK:
			zipper.close()
			return err
		err = zipper.write_file(bytes)
		if err != OK:
			zipper.close_file()
			zipper.close()
			return err
		zipper.close_file()
	return zipper.close()


func _build_manifest(course: IDCourseData, files: PackedStringArray) -> String:
	var lms := course.lms
	var ident := lms.identifier
	var title := lms.course_title.strip_edges()
	if title.is_empty() and not course.slides.is_empty() and course.slides[0] != null:
		title = course.slides[0].title.strip_edges()
	if title.is_empty():
		title = ident
	var org_id := "ORG-%s" % ident
	var item_id := "ITEM-%s" % ident
	var res_id := "RES-%s" % ident
	var mastery := _mastery_score(course)
	var lines: PackedStringArray = []
	lines.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
	lines.append("<manifest identifier=\"%s\" version=\"1.2\"" % _xml(ident))
	lines.append("  xmlns=\"http://www.imsproject.org/xsd/imscp_rootv1p1p2\"")
	lines.append("  xmlns:adlcp=\"http://www.adlnet.org/xsd/adlcp_rootv1p2\">")
	lines.append("  <metadata>")
	lines.append("    <schema>ADL SCORM</schema>")
	lines.append("    <schemaversion>1.2</schemaversion>")
	lines.append("  </metadata>")
	lines.append("  <organizations default=\"%s\">" % _xml(org_id))
	lines.append("    <organization identifier=\"%s\">" % _xml(org_id))
	lines.append("      <title>%s</title>" % _xml(title))
	lines.append("      <item identifier=\"%s\" identifierref=\"%s\">" % [_xml(item_id), _xml(res_id)])
	lines.append("        <title>%s</title>" % _xml(title))
	if mastery >= 0:
		lines.append("        <adlcp:masteryScore>%d</adlcp:masteryScore>" % mastery)
	lines.append("      </item>")
	lines.append("    </organization>")
	lines.append("  </organizations>")
	lines.append("  <resources>")
	lines.append("    <resource identifier=\"%s\" type=\"webcontent\" adlcp:scormtype=\"sco\" href=\"%s\">" % [_xml(res_id), _LAUNCH])
	var listed: Dictionary = {}
	for rel in files:
		var href := str(rel).replace("\\", "/")
		if listed.has(href):
			continue
		listed[href] = true
		lines.append("      <file href=\"%s\"/>" % _xml(href))
	if not listed.has(_MANIFEST_NAME):
		lines.append("      <file href=\"%s\"/>" % _MANIFEST_NAME)
	if not listed.has(_LAUNCH):
		lines.append("      <file href=\"%s\"/>" % _LAUNCH)
	lines.append("    </resource>")
	lines.append("  </resources>")
	lines.append("</manifest>")
	return "\n".join(lines) + "\n"


func _mastery_score(course: IDCourseData) -> int:
	for quiz_data in course.quizzes:
		if quiz_data == null or quiz_data.quiz_id.is_empty() or not quiz_data.report_to_lms:
			continue
		return int(quiz_data.passing_percent)
	return -1


func _xml(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")
