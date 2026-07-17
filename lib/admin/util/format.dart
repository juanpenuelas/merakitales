String slugify(String input) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  var s = input.toLowerCase().trim();
  for (var i = 0; i < from.length; i++) {
    s = s.replaceAll(from[i], to[i]);
  }
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  s = s.replaceAll(RegExp(r'^-+|-+$'), '');
  return s;
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatScheduled(DateTime dt) =>
    '${_two(dt.day)}/${_two(dt.month)} ${_two(dt.hour)}:${_two(dt.minute)}';
