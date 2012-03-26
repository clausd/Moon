use DateTime;
use DateTime::Format::ISO8601;

sub format_date {
    my $dt = shift;
    return sprintf("%04d%02d%02dT%02d%02d%02dZ", $dt->year,$dt->month,$dt->day,$dt->hour,$dt->minute,$dt->second);
}
print "BEGIN:VCALENDAR
VERSION:2.0
METHOD:PUBLISH
CALSCALE:GREGORIAN
X-WR-CALNAME:Live Moon Landing
";
while (my ($dtstr, @description) = split /\s/, <>) {
    my $dt = DateTime::Format::ISO8601->parse_datetime( $dtstr );
    $dt->add(hours=>-2);
    my $begin = format_date($dt);
    $dt->add(minutes=>15);
    my $end = format_date($dt);
    $text = join(' ', @description);
    $uid = $begin;
    $uid =~ s/W//g;
    print "BEGIN:VEVENT
DTSTART:$begin
DTEND:$end
LOCATION:Space
UID:$uid
DTSTAMP:$begin
SUMMARY:$text
DESCRIPTION:$text - follow the mission on http://classy.dk/moon/
PRIORITY:5
CLASS:PUBLIC
SEQUENCE:4
ATTACHMENT:http://classy.dk/moon/
END:VEVENT
";
}
print "END:VCALENDAR\n"

