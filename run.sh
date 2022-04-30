#!/bin/bash

set -x

function archive {
	curl "https://web.archive.org/save/$1" -s -L -o /dev/null -w "$1"
}

function youtube_playlist_previewer {
        PLAYLIST=$1

        TMPFILE=$RANDOM.txt

        youtube-dl -j --flat-playlist $PLAYLIST | jq -r '.id' > $TMPFILE

        FILENAME=index.html

	echo "<head>" > $FILENAME
        echo "<style>#images{ text-align:center; margin:50px auto; }" >> $FILENAME
        echo "#images a{margin:0px 20px; display:inline-block; text-decoration:none; color:black; }" >> $FILENAME
        echo ".caption { width: 150px; height: 80px; overflow-y: auto; }" >> $FILENAME
        echo "</style>" >> $FILENAME
	echo '<meta charset="UTF-8">' >> $FILENAME
	echo "</head>" >> $FILENAME
        echo '<div id="images">' >> $FILENAME

        cat $TMPFILE  | perl -lne 'while (<>) { 
                chomp; 
                $id = $_; 
                $title = q##;
                if(!-e qq#.$id# || -z qq#.$id#) {
			system(qq#youtube-dl --skip-download --get-title --no-warnings -- $id > .$id#);
                }
                $title = qx(cat .$id);
                print qq#<a href="https://youtube.com/watch?v=$id"><img src="https://i.ytimg.com/vi/$id/hqdefault.jpg" width="150px"><div class="caption">$title</div></a>\n#;
        }' >> $FILENAME

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
                                alert("Cannot get IDs");
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

	for ytvid in $(cat $FILENAME | grep 'href="https' | sed -e 's/.*href="//' | sed -e 's/".*//'); do
		curl -s -I https://web.archive.org/save/$ytvid
	done

        rm $TMPFILE
}

youtube_playlist_previewer $1
