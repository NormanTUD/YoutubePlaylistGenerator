#!/bin/bash


while [[ -e "tmp_index.html" ]]; do
        exit
done

function archive {
        echo "Archiving $1"
        curl "https://web.archive.org/save/https://www.youtube.com/watch?v=$1" -s -L -o /dev/null -w "https://www.youtube.com/watch?v=$1" 2>/dev/null >/dev/null
        touch ".${1}_archived"
}

function youtube_playlist_previewer {
        PLAYLIST=$1

        TMPFILE=$RANDOM.txt

        yt-dlp --no-check-certificate -j --flat-playlist $PLAYLIST | jq -r '.id' | tac > $TMPFILE

        FILENAME=tmp_index.html

        now=$(date)

        echo "<!DOCTYPE html>" > $FILENAME
        echo "<html>" >> $FILENAME
        echo "<head>" >> $FILENAME
        echo "<title>Playlist &mdash; $now</title>" >> $FILENAME
        echo "<style>#images{ text-align:center; margin:50px auto; }" >> $FILENAME
        echo "#images a{margin:0px 20px; display:inline-block; text-decoration:none; color:black; }" >> $FILENAME
        echo ".caption { width: 15vw; height: 10vh; overflow-y: auto; }" >> $FILENAME
        echo "img { width: 15vw; overflow-y: auto; }" >> $FILENAME
        echo "</style>" >> $FILENAME
        echo '<meta charset="UTF-8">' >> $FILENAME
        echo "</head>" >> $FILENAME
        echo '<div id="images">' >> $FILENAME

        cat $TMPFILE | perl -lne 'while (<>) {
                chomp; 
                $id = $_; 

                use HTTP::Tiny;
                my $Client = HTTP::Tiny->new();

                my $url = "https://i.ytimg.com/vi/$id/hqdefault.jpg";
                my $response = $Client->get($url);
                my $status_code = $response->{status};

                if($status_code == 200) {
                        $title = q##;

                        my $playable_in_embed;

                        my $playable_in_embed_file = ".playable_in_embed_$id";
                        my $playable_in_embed_file_is_too_old = (time - (stat $playable_in_embed_file)[9]) > (7*86400) && rand() >= 0.5;

                        if(!-e $playable_in_embed_file || -z $playable_in_embed_file || $playable_in_embed_file_is_too_old) {
                                warn "Downloading playable_in_embed for $id\n";
                                system(qq#yt-dlp --print "%(playable_in_embed)s" -- $id > $playable_in_embed_file#);
                        }

                        $playable_in_embed = qx(cat $playable_in_embed_file);

                        if($playable_in_embed !~ /True/) {
                                # sicherheitshalber nochmal downloaden wenn es false ist
                                warn "Downloading playable_in_embed for $id (again)\n";
                                system(qq#yt-dlp --print "%(playable_in_embed)s" -- $id > $playable_in_embed_file#);
                        }

                        $playable_in_embed = qx(cat $playable_in_embed_file);

                        if($playable_in_embed =~ /True/) {
                                if(!-e qq#.full_$id# || -z qq#.full_$id#) {
                                        warn "Downloading title for $id\n";
                                        system(qq#yt-dlp --print "%(title)s<br><br><br>Channel: <b>%(channel)s</b> - %(duration>%H:%M:%S)s" -- $id > .full_$id#);
                                }

                                $title = qx(cat .full_$id);
                                if($title) {
                                        my $availability;

                                        my $availability_file = ".availability_$id";
                                        my $availability_file_is_too_old = (time - (stat $availability_file)[9]) > (7*86400) && rand() >= 0.5;

                                        if(!-e $availability_file || -z $availability_file || $availability_file_is_too_old) {
                                                warn "Downloading availability for $id\n";
                                                system(qq#yt-dlp --print "%(availability)s" -- $id > $availability_file#);
                                        }

                                        $availability = qx(cat $availability_file);

                                        if($availability =~ m#public#i || $availability =~ m#unlisted#i) {
                                                print qq#<a href="https://youtube.com/watch?v=$id"><img src="https://i.ytimg.com/vi/$id/hqdefault.jpg"><div class="caption">$title</div></a>\n#;
                                        } else {
                                                warn qq#Availability for $id is >$availability<, not public or unlisted. Not listing\n#;
                                        }
                                }
                        } else {
                                warn qq#$id is not playable in embedded. Not listing it.\n#;
                        }
                } else {
                        warn "$id is not available.\n";
                }
        }' >> $FILENAME

        while read p; do
                if [[ ! -e ".${p}_archived" ]]; then
                        archive "$p"
                fi
        done < $TMPFILE

        echo "</div>" >> $FILENAME

        echo '
<center>
<button id="random" onclick="player.loadVideoById(get_random_ytid(0))">Next random video</button><br><br>
<div id="player"></div>
<center>

<script src="https://www.youtube.com/iframe_api"></script>

<script>
        var player;

        var anchors = document.getElementsByTagName("a");
        var youtube_ids = [];
        for(var i = 0; i < anchors.length; i++){
                youtube_ids.push(anchors[i].href.replace("https://youtube.com/watch?v=", ""));
        }

        function get_random_ytid (recursion) {
                if(youtube_ids.length) {
                        var index = Math.floor(Math.random()*youtube_ids.length);
                        var item = youtube_ids[index];
                        youtube_ids.splice(index, 1);
                } else {
                        if(recursion) {
                                console.warn("Cannot get IDs");
                        } else {
                                for(var i = 0; i < anchors.length; i++){
                                        youtube_ids.push(anchors[i].href.replace("https://youtube.com/watch?v=", ""));
                                }
                                item = get_random_ytid(1);
                        }
                }
                return item;

        }

        function onPlayerReady(event) {
                event.target.playVideo();
        }

        function onPlayerStateChange(event) {
                if(event.data === YT.PlayerState.ENDED) {
                        player.loadVideoById(get_random_ytid(0));
                }
        }

        function onYouTubePlayerAPIReady() {
                player = new YT.Player("player", {
                        height: "390",
                        width: "640",
                        videoId: get_random_ytid(0),
                        playerVars: { 
                                "autoplay": 1,
                                "controls": 1
                        },
                        events: {
                                "onReady": onPlayerReady,
                                "onStateChange": onPlayerStateChange
                        }
                });
        }
</script>
' >> $FILENAME
        echo "</html>" >> $FILENAME

        if [[ -e "index_old.html" ]]; then
                rm index_old.html
        fi

        if [[ -e "index.html" ]]; then
                mv index.html index_old.html
        fi

        mv $FILENAME index.html

        rm $TMPFILE
}

youtube_playlist_previewer $1
