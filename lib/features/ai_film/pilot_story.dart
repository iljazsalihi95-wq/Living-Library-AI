import 'film_models.dart';

/// Pilot story assembled from the approved 22-frame storyboard supplied by the owner.
/// Frames stay ordered inside each scene so a future image-to-video provider can
/// preserve the intended visual continuity instead of treating them as a slideshow.
const livingLibraryPilot = FilmProject(
  id: 'pilot_jamaah_27',
  title: 'Vlera e namazit me xhemat',
  language: FilmLanguage.sq,
  storyText: 'Një burrë qëndron gjatë në bisedë. Kur e kupton se koha ka kaluar, niset me nxitim drejt xhamisë, por arrin pasi xhemati ka përfunduar. Ai kthehet i penduar, kujton vlerën e namazit me xhemat dhe falet.',
  characters: [
    CharacterReference(id: 'guest', name: 'Mysafiri', visualNotes: 'Burrë me turban dhe mantel ngjyrë kafe; ruaj të njëjtën pamje në të gjitha skenat.'),
    CharacterReference(id: 'host', name: 'Mikpritësi', visualNotes: 'Burrë me turban të bardhë dhe mantel të gjelbër; ruaj të njëjtën pamje në skenat e bisedës.'),
  ],
  scenes: [
    FilmScene(id:'p01',title:'Vizita',storyText:'Dy burrat takohen në hyrje të shtëpisë.',motionInstructions:'Lëvizje e qetë; përshëndetje dhe hyrje në dhomë.',characterIds:['guest','host'],referenceImagePaths:['assets/story/frame_01.jpg','assets/story/frame_02.jpg','assets/story/frame_03.jpg']),
    FilmScene(id:'p02',title:'Biseda',storyText:'Ata ulen dhe vazhdojnë bisedën.',motionInstructions:'Gjeste natyrale të duarve; kamera e qetë.',characterIds:['guest','host'],referenceImagePaths:['assets/story/frame_04.jpg','assets/story/frame_05.jpg']),
    FilmScene(id:'p03',title:'Koha kalon',storyText:'Biseda vazhdon ndërsa nata avancon.',motionInstructions:'Kalimi i kohës të kuptohet nga ambienti dhe ora; pa ndryshuar personazhet.',characterIds:['guest','host'],referenceImagePaths:['assets/story/frame_06.jpg','assets/story/frame_07.jpg','assets/story/frame_08.jpg']),
    FilmScene(id:'p04',title:'E kupton vonesën',storyText:'Mysafiri shikon jashtë dhe habitet kur kupton sa vonë është.',motionInstructions:'Kthim drejt derës, pastaj reagim i befasuar.',characterIds:['guest'],referenceImagePaths:['assets/story/frame_09.jpg','assets/story/frame_10.jpg']),
    FilmScene(id:'p05',title:'Niset me nxitim',storyText:'Ai del nga shtëpia dhe niset drejt xhamisë.',motionInstructions:'Ecje që kalon në vrapim; mantel që lëviz natyrshëm.',characterIds:['guest'],referenceImagePaths:['assets/story/frame_11.jpg']),
    FilmScene(id:'p06',title:'Rruga drejt xhamisë',storyText:'Ai vrapon nëpër rrugën e natës drejt xhamisë.',motionInstructions:'Kamera e ndjek nga pas; ruaj hënën, ndriçimin dhe arkitekturën.',characterIds:['guest'],referenceImagePaths:['assets/story/frame_12.jpg']),
    FilmScene(id:'p07',title:'Mbërritja',storyText:'Ai arrin pranë xhamisë.',motionInstructions:'Ngadalëson hapin ndërsa afrohet te oborri.',characterIds:['guest'],referenceImagePaths:['assets/story/frame_13.jpg']),
    FilmScene(id:'p08',title:'Xhemati ka përfunduar',storyText:'Ai sheh njerëzit duke dalë nga xhamia.',motionInstructions:'Turma largohet qetë; personazhi kryesor mbetet në plan të parë.',characterIds:['guest'],referenceImagePaths:['assets/story/frame_14.jpg']),
    FilmScene(id:'p09',title:'Oborri zbrazet',storyText:'Oborri i xhamisë zbrazet dhe ai mbetet vetëm.',motionInstructions:'Pakëso njerëzit gradualisht deri në oborr bosh.',characterIds:['guest'],referenceImagePaths:['assets/story/frame_15.jpg','assets/story/frame_16.jpg','assets/story/frame_17.jpg']),
    FilmScene(id:'p10',title:'Kthimi',storyText:'Ai kthehet i dëshpëruar drejt shtëpisë.',motionInstructions:'Ecje e ngadaltë me kokën ulur.',characterIds:['guest'],referenceImagePaths:['assets/story/frame_18.jpg','assets/story/frame_19.jpg']),
    FilmScene(id:'p11',title:'Kujtesa',storyText:'Ai mendon për vlerën e namazit me xhemat: njëzet e shtatë shkallë.',motionInstructions:'Kalimi në reflektim vizual; mos shto tekst tjetër fetar përveç materialit të miratuar.',characterIds:['guest'],referenceImagePaths:['assets/story/frame_20.jpg']),
    FilmScene(id:'p12',title:'Namazi',storyText:'Ai ngrihet për namaz dhe përfundon në sexhde.',motionInstructions:'Lëvizje e qetë dhe respektuese; mbyllje me sexhde.',characterIds:['guest'],referenceImagePaths:['assets/story/frame_21.jpg','assets/story/frame_22.jpg']),
  ],
);
