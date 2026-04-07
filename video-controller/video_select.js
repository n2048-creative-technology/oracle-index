

videos=  [];
video_formats =  [];
played_videos =  [];

function init(){
	videos = [
		{
			path: 'path/to/video',
			format: '3:4',
		}
	]

	video_formats = [
		'16:9',
		'9:16',
		'4:3',
		'1:1'
	];

	played_videos = [];
}

/*
// rules: 
- same video should never be played 2 times in a row. 
- same video foremat should never be played 2 times in a row. 
*/

previous_format = null;
previous_video = null;

current_format = null;
current_video = null;

//probabilityes: 20%,20%,20%,40%:
function choose_next_format(prefferred_format){	

	if(current_format != prefferred_format) return prefferred_format;

	format_choice = random(100);
	if(format_choice <20 ) next_format = '1:1';
	else if(format_choice <40 ) next_format = '4:3';
	else if(format_choice <60 ) next_format = '9:16';
	else next_format = '16:9';
	if(current_format != next_format) return next_format;
	else return choose_next_format();
}

function choose_next_video(format){	
	formatted_videos = videos.map(v=>{v.format})
	video_choice = random(formatted_videos.length();	
	next_video = formatted_videos[video_choice]

	if(current_video != next_video) return next_video;
	else return choose_next_video(format);
}

function get_prefferred_format() {
	// based on last minier node, choose format:	
	// To implement:
	last_minier = 1; // check from system logs;

	prefferred_format = video_formats[last_minier];
	return prefferred_format;
}

function wait_for_video_stop(){
	video_is_playing = false;
	while(video_is_playing) return wait_for_video_stop();
	return true;
}

function play(video_path) {
		// implement 
}


function loop(){

	// wait till no video is playing: (implement socket comm with MVP)
	// ... 
	wait_for_video_stop();

	if(videos.len()==0)  init();

	## prefferred_format comes from the last mining node:

	prefferred_format = get_prefferred_format();

	next_format = choose_next_format(prefferred_format);
	next_video = choose_next_video(next_format)

	played_videos.push(videos.pull(next_video));

	play(next_video.path)

}


loop();
