concrete PrimaRulesEng of PrimaRules = CatEng ** PrimaRulesI with (Cat=CatEng),(Syntax=SyntaxEng),(Extra = ExtraEng),(Conjunction=ConjunctionEng) ** open ResEng, Prelude in {
  lincat CS = SS ;
  lin
    --    ppartAP v2 = { s = \\_ => v2.s ! VPPart ; isPre = True } ;
    useS s = s ;
};