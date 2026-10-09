import Foundation

enum FuturesChartLink {
    static func url(for instrument: Instrument, quoteSymbol: String? = nil) -> URL? {
        if let code = instrument.eastMoneyMainCode {
            let parts = code.split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count == 2, parts[0].allSatisfy(\.isNumber), !parts[0].isEmpty,
                  String(parts[1]).range(of: "^[A-Za-z]+[mM]$", options: .regularExpression) != nil else { return nil }
            // Preserve the provider's case: CZCE and CFFEX use uppercase symbols.
            return URL(string: "https://quote.eastmoney.com/qihuo/\(parts[1]).html")
        }
        // Nodes such as pta_qh and qz_qh are not contract symbols. Keep an explicit
        // mapping so a chart remains available before the first successful quote.
        let symbol = sinaProducts[instrument.id].map { $0 + "0" } ?? quoteSymbol
        guard let symbol, symbol.range(of: "^[A-Za-z]+0$", options: .regularExpression) != nil else { return nil }
        return URL(string: "https://finance.sina.com.cn/futures/quotes/\(symbol.uppercased()).shtml")
    }

    private static let sinaProducts: [String: String] = [
        "pta_qh": "TA", "czy_qh": "OI", "ycz_qh": "RS", "czp_qh": "RM", "dlm_qh": "ZC",
        "qm_qh": "WH", "jdm_qh": "JR", "bst_qh": "SR", "mh_qh": "CF", "zxd_qh": "RI",
        "zc_qh": "MA", "bl_qh": "FG", "wxd_qh": "LR", "gt_qh": "SF", "mg_qh": "SM",
        "ms_qh": "CY", "xpg_qh": "AP", "hz_qh": "CJ", "ns_qh": "UR", "cj_qh": "SA",
        "pf_qh": "PF", "pk_qh": "PK", "sh_qh": "SH", "px_qh": "PX", "pr_qh": "PR", "pl_qh": "PL",
        "pvc_qh": "V", "zly_qh": "P", "de_qh": "B", "dp_qh": "M", "tks_qh": "I",
        "jd_qh": "JD", "lldpe_qh": "L", "jbx_qh": "PP", "xwb_qh": "FB", "jhb_qh": "BB",
        "dy_qh": "Y", "hym_qh": "C", "dd_qh": "A", "jt_qh": "J", "jm_qh": "JM",
        "ymdf_qh": "CS", "yec_qh": "EG", "gm_qh": "RR", "byx_qh": "EB", "pg_qh": "PG",
        "lh_qh": "LH", "lg_qh": "LG", "bz_qh": "BZ",
        "ry_qh": "FU", "yy_qh": "SC", "lv_qh": "AL", "xj_qh": "RU", "xing_qh": "ZN",
        "tong_qh": "CU", "hj_qh": "AU", "lwg_qh": "RB", "xc_qh": "WR", "qian_qh": "PB",
        "by_qh": "AG", "lq_qh": "BU", "rzjb_qh": "HC", "xi_qh": "SN", "ni_qh": "NI",
        "zj_qh": "SP", "ehj_qh": "NR", "bxg_qh": "SS", "lu_qh": "LU", "bc_qh": "BC",
        "ao_qh": "AO", "br_qh": "BR", "ec_qh": "EC", "ad_qh": "AD", "op_qh": "OP",
        "qz_qh": "IF", "gz_qh": "TF", "sngz_qh": "T", "szgz_qh": "IH", "zzgz_qh": "IC",
        "engz_qh": "TS", "im_qh": "IM",
        "si_qh": "SI", "lc_qh": "LC", "ps_qh": "PS", "pt_qh": "PT", "pd_qh": "PD"
    ]
}
