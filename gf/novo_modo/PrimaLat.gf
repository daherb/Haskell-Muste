--# -path=/home/herb/src/own/GF-latin
concrete PrimaLat of Prima = CatLat ** open Prelude,ParadigmsLat,LexiconLat,StructuralLat,IrregLat,SentenceLat,NounLat,VerbLat,AdjectiveLat,ExtraLat,(R = ResLat),ConjunctionLat,TenseX,ParamX in {
  lin
    a_A = { s = \\_,_ => "*Adjective" };
    pn_PN = { s = \\_,_ => "*ProperName" ; g = neuter } ;
    n_N = { s = \\_,_ => "*Noun" ; g = neuter } ;
    adv_Adv = { s = "*Adverb" } ;
    v_V = { act = \\_ => "*IntransitiveVerb" ; ger = \\_ => "*IntransitiveVerb" ; geriv = \\_ => "*IntransitiveVerb" ; imp = \\_ => "*IntransitiveVerb" ; inf = \\_ => "*IntransitiveVerb" ; part = \\_,_ => "*IntransitiveVerb" ; pass = \\_ => "*IntransitiveVerb" ; sup = \\_ => "*IntransitiveVerb" } ;
    v2_V2 = { act = \\_ => "*TransitiveVerb" ; ger = \\_ => "*TransitiveVerb" ; geriv = \\_ => "*TransitiveVerb" ; imp = \\_ => "*TransitiveVerb" ; inf = \\_ => "*TransitiveVerb" ; part = \\_,_ => "*TransitiveVerb" ; pass = \\_ => "*TransitiveVerb" ; sup = \\_ => "*TransitiveVerb" ; c = { s = [] ; c = R.Acc ; isPost = True } } ;
    ap_AP = { s = \\_ => "*AdjectivePhrase" ; isPre = True } ;
    vp_VP = { s = \\_,_ => "*VerbPhrase" ; compl = \\_ => [] ; obj = [] ; part = \\_,_ => []} ;
    np_NP = { s = \\_ => "*NounPhrase" ; g = neuter ; n = R.Sg ; p = P3 };
    s_S = { s = "*Sentence" };
    externus_A = mkA "externus" ;
    magnus_A = LexiconLat.big_A ;
    multus_A = mkA "multus" ;
    Romanus_A = mkA "Romanus" ;
    saepe_Adv = mkAdv "saepe" ;
    Caesar_N = (mkN "Caesar" "Caesaris" masculine) ;
    civitas_N = mkN "civitas" "civitatis" feminine ;
    Germanus_N = mkN "Germanus" ;
    hostis_N = mkN "hostis" "hostis" masculine ;
    imperator_N = mkN "imperator" "imperatoris" masculine ;
    imperium_N = mkN "imperium" ;
    provincia_N = mkN "provincia" ;
    Augustus_PN = mkPN (mkN "Augustus") ;
    Gallia_PN = mkPN (mkN "Gallia") ;
    Africa_PN = mkPN (mkN "Africa") ;
    dicere_V = mkV "dicere" "dico" "dixi" "dictum" ;
--    esse_V = be_V ;
    devenire_V2 = mkV2 (mkV "devenire") (lin Prep R.Nom_Prep);
    habere_V2 = StructuralLat.have_V2 ;
    tenere_V2 = LexiconLat.hold_V2 ;
    vincere_V2 = LexiconLat.win_V2 ;
    he_PP = he_Pron ;
    lesson1APfromA = PositA ;
    lesson1APfromV2 v2 = PastPartAP (SlashV2a v2);
    lesson1ClfromNPVP = PredVP ;
    lesson1NPfromPN = UsePN ;
    lesson1NPfromPron = UsePron ;
    lesson1NPfromCNsg cn = DetCN (DetQuant DefArt NumSg) cn ;
    lesson1NPfromCNpl cn = DetCN (DetQuant DefArt NumPl) cn ;
    lesson1NPfromNPandNP np1 np2 = ConjNP and_Conj (BaseNP np1 np2) ;
    lesson1CNfromN = UseN ;
    lesson1CNfromAPCN a cn = (AdjCN a cn) ;
    lesson1CNfromCNNP = ApposCN ;
    lesson1VPfromV = UseV ;
    lesson1VPfromV2NP v2 np = ComplSlash (SlashV2a v2) np ;
    lesson1VPfromA a = UseComp (CompAP (PositA a)) ;
    lesson1VPfromCN cn = UseComp (CompCN cn) ;
    lesson1SfromCl = UseCl (TTAnt TPres ASimul) PPos ;
    lesson1SfromAdvS = AdvS ;
}