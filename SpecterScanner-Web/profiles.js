/**
 * profiles.js
 * Doll profile data for the Specter Scanner web app.
 * Each profile contains identification, haunting classification, backstory,
 * documented paranormal activity, and current containment status.
 */

const HAUNTING_TYPES = {
  whisperer: {
    displayName: "Whisperer",
    icon: "\uD83D\uDD0A",
    description:
      "Entities that produce faint vocalizations, sub-audible sounds, or influence nearby audio equipment. Whisperers communicate through sound just below — or just beyond — the edge of hearing.",
  },
  watcher: {
    displayName: "Watcher",
    icon: "\uD83D\uDC41",
    description:
      "Entities that generate an unmistakable sensation of being observed. Watchers are associated with unexplained light anomalies in their eyes, motion-sensor triggers, and thermal signatures around the head region.",
  },
  mover: {
    displayName: "Mover",
    icon: "\uD83E\uDEF3",
    description:
      "Entities linked to the unexplained displacement of physical objects. Movers rearrange, reposition, or redirect nearby items — sometimes with surprising precision.",
  },
  weeper: {
    displayName: "Weeper",
    icon: "\uD83D\uDCA7",
    description:
      "Entities associated with moisture, cold spots, and feelings of deep sadness. Weepers are among the most emotionally affecting entities on record and are generally considered low-threat.",
  },
  mimic: {
    displayName: "Mimic",
    icon: "\uD83C\uDFAD",
    description:
      "Entities capable of reproducing human voices, sounds, or electronic signals with disturbing accuracy. Mimics often replicate the voices of people known to those nearby.",
  },
  trickster: {
    displayName: "Trickster",
    icon: "\uD83C\uDCCF",
    description:
      "Entities that cause mischievous, often playful disruptions — from harmless pranks to cascading electronics failures. Tricksters range from lighthearted to dangerously unpredictable.",
  },
};

const DOLL_PROFILES = [
  {
    id: "doll_01",
    classificationLabel: "marguerite",
    name: "Marguerite",
    hauntingType: "mover",
    hauntingIcon: "\uD83E\uDEF3",
    threatLevel: 3,
    originStory:
      "Recovered from a sealed cedar chest in an abandoned Savannah estate. The previous owners reported furniture rearranging itself every night after they placed Marguerite on the mantelpiece. She was found facing the front door, though no one had touched her in weeks.",
    documentedActivity: [
      "Rocking chair displaced 14 inches from original position overnight.",
      "Kitchen cabinet doors discovered open on three consecutive mornings.",
      "EMF detector registered a sustained 4.7 mG spike within a two-foot radius.",
      "A stack of books was found rearranged in reverse alphabetical order.",
    ],
    status: "under_observation",
  },
  {
    id: "doll_02",
    classificationLabel: "little_edwin",
    name: "Little Edwin",
    hauntingType: "weeper",
    hauntingIcon: "\uD83D\uDCA7",
    threatLevel: 2,
    originStory:
      "Little Edwin was found sitting alone on a rain-soaked park bench in Portland, Oregon. No one claimed him. Staff at the lost-and-found reported hearing faint crying from the storage closet where he was kept. Condensation forms on nearby windows whenever he is in the room.",
    documentedActivity: [
      "Persistent cold spot detected within three feet of the doll, averaging 12 degrees below ambient.",
      "Faint sobbing recorded on audio equipment between 2:00 and 3:00 AM.",
      "Unexplained moisture found pooled beneath the display shelf each morning.",
      "A researcher reported feeling overwhelming sadness when making direct eye contact.",
    ],
    status: "under_observation",
  },
  {
    id: "doll_03",
    classificationLabel: "the_duchess",
    name: "The Duchess",
    hauntingType: "watcher",
    hauntingIcon: "\uD83D\uDC41",
    threatLevel: 4,
    originStory:
      "Acquired at a London estate auction, The Duchess arrived in a velvet-lined case with a handwritten note reading 'She does not like to be ignored.' Multiple security cameras have captured her glass eyes reflecting light when no light source is present. Researchers unanimously report the sensation of being scrutinized.",
    documentedActivity: [
      "Security footage shows brief light reflections in the doll's eyes at 11:47 PM with no identifiable source.",
      "Three researchers independently reported intense feelings of being watched from behind.",
      "Infrared scan revealed unexplained thermal signature around the doll's head region.",
      "A motion sensor triggered four times in a sealed, empty room containing only The Duchess.",
    ],
    status: "contained",
  },
  {
    id: "doll_04",
    classificationLabel: "penelope",
    name: "Penelope",
    hauntingType: "whisperer",
    hauntingIcon: "\uD83D\uDD0A",
    threatLevel: 2,
    originStory:
      "Penelope was donated to a charity shop in New England by an elderly woman who said the doll had been 'trying to tell her something for forty years.' Audio analysis of ambient recordings near Penelope reveals faint vocalizations just below the threshold of human hearing, described by software as phonetically consistent with lullabies.",
    documentedActivity: [
      "Directional microphone captured sub-audible vocalizations matching the melody of 'Lavender's Blue.'",
      "White noise generator placed nearby produced brief, structured interference patterns.",
      "A child visitor claimed Penelope told her where to find a lost earring, which was subsequently located.",
      "Audio spectrum analysis shows recurring frequency anomalies between 16 Hz and 18 Hz.",
    ],
    status: "under_observation",
  },
  {
    id: "doll_05",
    classificationLabel: "captain_ashworth",
    name: "Captain Ashworth",
    hauntingType: "mover",
    hauntingIcon: "\uD83E\uDEF3",
    threatLevel: 3,
    originStory:
      "A hand-carved sailor doll discovered in the wreckage of a decommissioned lighthouse on the Maine coast. Captain Ashworth smells faintly of sea salt regardless of environment. Small objects in his vicinity tend to drift toward magnetic north, and compasses spin erratically when brought within arm's reach.",
    documentedActivity: [
      "Compass needle observed spinning continuously for 47 seconds at a distance of two feet.",
      "Small metallic objects found clustered against the north wall of the containment room.",
      "Faint smell of brine reported by all staff entering the room, despite air filtration.",
      "The doll was found facing the window overlooking the parking lot, repositioned from its shelf.",
    ],
    status: "under_observation",
  },
  {
    id: "doll_06",
    classificationLabel: "rosalind",
    name: "Rosalind",
    hauntingType: "mimic",
    hauntingIcon: "\uD83C\uDFAD",
    threatLevel: 4,
    originStory:
      "Rosalind was confiscated from a daycare in Austin, Texas, after multiple children reported hearing their mothers calling them from the empty supply closet where Rosalind was stored. Voice analysis confirmed the mimicked voices matched the actual parents with unsettling accuracy.",
    documentedActivity: [
      "Audio recording captured a voice matching Researcher Chen's mother calling his childhood nickname.",
      "Two staff members heard their own voices coming from the storage room while they were elsewhere.",
      "A child's laughter was recorded in the room at 4:12 AM; no children were present in the building.",
      "Phone placed near Rosalind recorded a voicemail playback that was never triggered.",
    ],
    status: "contained",
  },
  {
    id: "doll_07",
    classificationLabel: "the_twins",
    name: "The Twins",
    hauntingType: "trickster",
    hauntingIcon: "\uD83C\uDCCF",
    threatLevel: 5,
    originStory:
      "A matched pair of porcelain dolls purchased separately at two different antique shops over 200 miles apart on the same afternoon. When placed in separate rooms, they are invariably found together by morning. Electronics malfunction in cascading patterns when both are present, and staff have reported hearing faint giggling from air vents.",
    documentedActivity: [
      "Separated into rooms on different floors; found side by side on a hallway bench at 6:00 AM.",
      "Overhead fluorescent lights in the east wing flickered in a sequential wave pattern for eleven minutes.",
      "All desktop computers in the adjacent office rebooted simultaneously at 3:33 AM.",
      "Security guard reported hearing children's laughter echoing through the ventilation system.",
    ],
    status: "contained",
  },
  {
    id: "doll_08",
    classificationLabel: "baby_mae",
    name: "Baby Mae",
    hauntingType: "weeper",
    hauntingIcon: "\uD83D\uDCA7",
    threatLevel: 1,
    originStory:
      "Baby Mae was found tucked into a cradle in the attic of a demolished Victorian home in Charleston. She appears to be no more than a simple cloth baby doll, but anyone who holds her reports a gentle warmth and a faint heartbeat-like vibration. She seems more lonely than frightening.",
    documentedActivity: [
      "Thermal imaging shows Baby Mae maintains a surface temperature 2.3 degrees above ambient at all times.",
      "A faint rhythmic vibration at 72 beats per minute was detected using a seismograph.",
      "Staff member reported an overwhelming urge to comfort the doll when picking it up for examination.",
      "A small tear-shaped moisture stain appears on the cradle fabric each morning and evaporates by noon.",
    ],
    status: "under_observation",
  },
  {
    id: "doll_09",
    classificationLabel: "professor_wickham",
    name: "Professor Wickham",
    hauntingType: "trickster",
    hauntingIcon: "\uD83C\uDCCF",
    threatLevel: 3,
    originStory:
      "Professor Wickham is a bespectacled gentleman doll found in the rare books section of a university library after closing. The library had been locked, and no record exists of who left him there. Books near him are frequently found open to peculiar pages, and library computers display garbled text that occasionally forms coherent, sardonic sentences.",
    documentedActivity: [
      "A library terminal displayed the sentence 'You are looking in the wrong section' before returning to the login screen.",
      "Seven books were found open to pages containing the word 'spectacle' or 'spectacles.'",
      "The card catalog system briefly listed a nonexistent book titled 'Wickham's Compendium of Unseen Things.'",
      "A researcher's notes were found rearranged into a limerick overnight.",
    ],
    status: "under_observation",
  },
  {
    id: "doll_10",
    classificationLabel: "constance",
    name: "Constance",
    hauntingType: "watcher",
    hauntingIcon: "\uD83D\uDC41",
    threatLevel: 2,
    originStory:
      "Constance is an antique porcelain doll found bricked into a wall cavity during a home renovation in Sleepy Hollow, New York. Her painted eyes are remarkably detailed, and photographs of her consistently show a faint luminance around the irises that is not visible to the naked eye. She has a calming, if slightly eerie, presence.",
    documentedActivity: [
      "Photographs taken with flash reveal a faint greenish glow around the doll's painted irises.",
      "Security personnel report feeling watched but describe the sensation as protective rather than hostile.",
      "A night-vision camera recorded the ambient light level increasing by 0.3 lux in a sealed dark room.",
      "Researchers noted that arguments tend to de-escalate quickly when conducted in Constance's presence.",
    ],
    status: "under_observation",
  },
  {
    id: "doll_11",
    classificationLabel: "jolly_pete",
    name: "Jolly Pete",
    hauntingType: "trickster",
    hauntingIcon: "\uD83C\uDCCF",
    threatLevel: 2,
    originStory:
      "Jolly Pete is a painted wooden clown doll discovered in the crawl space beneath a retired carnival funhouse in Coney Island. Despite his garish grin, Pete seems more playful than menacing. Small harmless pranks occur around him: shoelaces tie themselves, pens vanish and reappear in coat pockets, and vending machines occasionally dispense an extra snack.",
    documentedActivity: [
      "A researcher's shoelaces were found double-knotted after being left untied during a bathroom break.",
      "The breakroom vending machine dispensed two candy bars for the price of one on three separate occasions.",
      "A pen that had been missing for a week was found balanced upright on Jolly Pete's outstretched hand.",
      "Faint calliope music was recorded at 28 dB in the storage room at exactly noon for four days running.",
    ],
    status: "under_observation",
  },
  {
    id: "doll_12",
    classificationLabel: "lady_vesper",
    name: "Lady Vesper",
    hauntingType: "whisperer",
    hauntingIcon: "\uD83D\uDD0A",
    threatLevel: 5,
    originStory:
      "Lady Vesper was recovered from a locked iron box buried beneath the floorboards of a condemned opera house in Vienna. The box bore an engraved warning in Latin: 'Do not open after sundown.' Her whispers are louder and more distinct than any other whisperer-class entity on record, and multiple listeners have reported hearing complete sentences in languages they do not speak.",
    documentedActivity: [
      "Directional microphones captured a full sentence in archaic German translating to 'The final act has not yet begun.'",
      "An audio engineer reported hearing operatic singing in an empty hallway adjacent to the containment room.",
      "EVP session recorded 14 distinct vocalizations in a 30-minute window, the highest count on file.",
      "All clocks in the east corridor stopped simultaneously at 8:47 PM and resumed at 8:49 PM.",
    ],
    status: "contained",
  },
];
