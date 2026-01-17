//-----------------------------------------------------------------
//                         biRISC-V CPU
//                            V0.8.1
//                     Ultra-Embedded.com
//                     Copyright 2019-2020
//
//                   admin@ultra-embedded.com
//
//                     License: Apache 2.0
//-----------------------------------------------------------------
// Copyright 2020 Ultra-Embedded.com
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//-----------------------------------------------------------------
`include "biriscv_defs.v"

module biriscv_decoder
(
     input                        valid_i
    ,input                        fetch_fault_i
    ,input                        enable_muldiv_i
    ,input                        enable_vector_extension_i //new
    ,input  [31:0]                opcode_i

    ,output                       invalid_o
    ,output                       exec_o
    ,output                       lsu_o
    ,output                       branch_o
    ,output                       mul_o
    ,output                       div_o
    ,output                       csr_o
    ,output                       rd_valid_o
    ,output                       lsu_v_o //new
    ,output                       alu_v_o //new
);

// Invalid instruction
wire invalid_w =    valid_i && 
                   ~(((opcode_i & `INST_ANDI_MASK) == `INST_ANDI)             ||
                    ((opcode_i & `INST_ADDI_MASK) == `INST_ADDI)              ||
                    ((opcode_i & `INST_SLTI_MASK) == `INST_SLTI)              ||
                    ((opcode_i & `INST_SLTIU_MASK) == `INST_SLTIU)            ||
                    ((opcode_i & `INST_ORI_MASK) == `INST_ORI)                ||
                    ((opcode_i & `INST_XORI_MASK) == `INST_XORI)              ||
                    ((opcode_i & `INST_SLLI_MASK) == `INST_SLLI)              ||
                    ((opcode_i & `INST_SRLI_MASK) == `INST_SRLI)              ||
                    ((opcode_i & `INST_SRAI_MASK) == `INST_SRAI)              ||
                    ((opcode_i & `INST_LUI_MASK) == `INST_LUI)                ||
                    ((opcode_i & `INST_AUIPC_MASK) == `INST_AUIPC)            ||
                    ((opcode_i & `INST_ADD_MASK) == `INST_ADD)                ||
                    ((opcode_i & `INST_SUB_MASK) == `INST_SUB)                ||
                    ((opcode_i & `INST_SLT_MASK) == `INST_SLT)                ||
                    ((opcode_i & `INST_SLTU_MASK) == `INST_SLTU)              ||
                    ((opcode_i & `INST_XOR_MASK) == `INST_XOR)                ||
                    ((opcode_i & `INST_OR_MASK) == `INST_OR)                  ||
                    ((opcode_i & `INST_AND_MASK) == `INST_AND)                ||
                    ((opcode_i & `INST_SLL_MASK) == `INST_SLL)                ||
                    ((opcode_i & `INST_SRL_MASK) == `INST_SRL)                ||
                    ((opcode_i & `INST_SRA_MASK) == `INST_SRA)                ||
                    ((opcode_i & `INST_JAL_MASK) == `INST_JAL)                ||
                    ((opcode_i & `INST_JALR_MASK) == `INST_JALR)              ||
                    ((opcode_i & `INST_BEQ_MASK) == `INST_BEQ)                ||
                    ((opcode_i & `INST_BNE_MASK) == `INST_BNE)                ||
                    ((opcode_i & `INST_BLT_MASK) == `INST_BLT)                ||
                    ((opcode_i & `INST_BGE_MASK) == `INST_BGE)                ||
                    ((opcode_i & `INST_BLTU_MASK) == `INST_BLTU)              ||
                    ((opcode_i & `INST_BGEU_MASK) == `INST_BGEU)              ||
                    ((opcode_i & `INST_LB_MASK) == `INST_LB)                  ||
                    ((opcode_i & `INST_LH_MASK) == `INST_LH)                  ||
                    ((opcode_i & `INST_LW_MASK) == `INST_LW)                  ||
                    ((opcode_i & `INST_LBU_MASK) == `INST_LBU)                ||
                    ((opcode_i & `INST_LHU_MASK) == `INST_LHU)                ||
                    ((opcode_i & `INST_LWU_MASK) == `INST_LWU)                ||
                    ((opcode_i & `INST_SB_MASK) == `INST_SB)                  ||
                    ((opcode_i & `INST_SH_MASK) == `INST_SH)                  ||
                    ((opcode_i & `INST_SW_MASK) == `INST_SW)                  ||
                    ((opcode_i & `INST_ECALL_MASK) == `INST_ECALL)            ||
                    ((opcode_i & `INST_EBREAK_MASK) == `INST_EBREAK)          ||
                    ((opcode_i & `INST_ERET_MASK) == `INST_ERET)              ||
                    ((opcode_i & `INST_CSRRW_MASK) == `INST_CSRRW)            ||
                    ((opcode_i & `INST_CSRRS_MASK) == `INST_CSRRS)            ||
                    ((opcode_i & `INST_CSRRC_MASK) == `INST_CSRRC)            ||
                    ((opcode_i & `INST_CSRRWI_MASK) == `INST_CSRRWI)          ||
                    ((opcode_i & `INST_CSRRSI_MASK) == `INST_CSRRSI)          ||
                    ((opcode_i & `INST_CSRRCI_MASK) == `INST_CSRRCI)          ||
                    ((opcode_i & `INST_WFI_MASK) == `INST_WFI)                ||
                    ((opcode_i & `INST_FENCE_MASK) == `INST_FENCE)            ||
                    ((opcode_i & `INST_IFENCE_MASK) == `INST_IFENCE)          ||
                    ((opcode_i & `INST_SFENCE_MASK) == `INST_SFENCE)          ||
                    (enable_muldiv_i && (opcode_i & `INST_MUL_MASK) == `INST_MUL)       ||
                    (enable_muldiv_i && (opcode_i & `INST_MULH_MASK) == `INST_MULH)     ||
                    (enable_muldiv_i && (opcode_i & `INST_MULHSU_MASK) == `INST_MULHSU) ||
                    (enable_muldiv_i && (opcode_i & `INST_MULHU_MASK) == `INST_MULHU)   ||
                    (enable_muldiv_i && (opcode_i & `INST_DIV_MASK) == `INST_DIV)       ||
                    (enable_muldiv_i && (opcode_i & `INST_DIVU_MASK) == `INST_DIVU)     ||
                    (enable_muldiv_i && (opcode_i & `INST_REM_MASK) == `INST_REM)       ||
                    (enable_muldiv_i && (opcode_i & `INST_REMU_MASK) == `INST_REMU)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VLE8_V_MASK)  == `INST_VLE8_V)      ||
                    (enable_vector_extension_i && (opcode_i & `INST_VLE16_V_MASK) == `INST_VLE16_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VLE32_V_MASK) == `INST_VLE32_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VLE64_V_MASK) == `INST_VLE64_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VSE8_V_MASK)  == `INST_VSE8_V)      ||
                    (enable_vector_extension_i && (opcode_i & `INST_VSE16_V_MASK) == `INST_VSE16_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VSE32_V_MASK) == `INST_VSE32_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VSE64_V_MASK) == `INST_VSE64_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VL1RE8_V_MASK) == `INST_VL1RE8_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VL1RE16_V_MASK) == `INST_VL1RE16_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VL1RE32_V_MASK) == `INST_VL1RE32_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VL1RE64_V_MASK) == `INST_VL1RE64_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VL2RE8_V_MASK) == `INST_VL2RE8_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VL2RE16_V_MASK) == `INST_VL2RE16_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VL2RE32_V_MASK) == `INST_VL2RE32_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VL2RE64_V_MASK) == `INST_VL2RE64_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VL4RE8_V_MASK) == `INST_VL4RE8_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VL4RE16_V_MASK) == `INST_VL4RE16_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VL4RE32_V_MASK) == `INST_VL4RE32_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VL4RE64_V_MASK) == `INST_VL4RE64_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VL8RE8_V_MASK) == `INST_VL8RE8_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VL8RE16_V_MASK) == `INST_VL8RE16_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VL8RE32_V_MASK) == `INST_VL8RE32_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VL8RE64_V_MASK) == `INST_VL8RE64_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VS1R_V_MASK) == `INST_VS1R_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VS2R_V_MASK) == `INST_VS2R_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VS4R_V_MASK) == `INST_VS4R_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VS8R_V_MASK) == `INST_VS8R_V)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VADD_VI_MASK) == `INST_VADD_VI)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VADD_VV_MASK) == `INST_VADD_VV)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VADD_VX_MASK) == `INST_VADD_VX)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VMV_V_X_MASK) == `INST_VMV_V_X)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VSUB_VV_MASK) == `INST_VSUB_VV)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VSUB_VX_MASK) == `INST_VSUB_VX)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VRSUB_VI_MASK) == `INST_VRSUB_VI)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VRSUB_VX_MASK) == `INST_VRSUB_VX)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VMINU_VV_MASK) == `INST_VMINU_VV)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VMINU_VX_MASK) == `INST_VMINU_VX)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VMAXU_VV_MASK) == `INST_VMAXU_VV)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VMAXU_VX_MASK) == `INST_VMAXU_VX)     ||
                    (enable_vector_extension_i && (opcode_i & `INST_VMUL_VV_MASK) == `INST_VMUL_VV)       ||
                    (enable_vector_extension_i && (opcode_i & `INST_VREDSUM_VS_MASK) == `INST_VREDSUM_VS)
                    );

assign invalid_o = invalid_w;

assign rd_valid_o = ((opcode_i & `INST_JALR_MASK) == `INST_JALR)     ||
                    ((opcode_i & `INST_JAL_MASK) == `INST_JAL)       ||
                    ((opcode_i & `INST_LUI_MASK) == `INST_LUI)       ||
                    ((opcode_i & `INST_AUIPC_MASK) == `INST_AUIPC)   ||
                    ((opcode_i & `INST_ADDI_MASK) == `INST_ADDI)     ||
                    ((opcode_i & `INST_SLLI_MASK) == `INST_SLLI)     ||
                    ((opcode_i & `INST_SLTI_MASK) == `INST_SLTI)     ||
                    ((opcode_i & `INST_SLTIU_MASK) == `INST_SLTIU)   ||
                    ((opcode_i & `INST_XORI_MASK) == `INST_XORI)     ||
                    ((opcode_i & `INST_SRLI_MASK) == `INST_SRLI)     ||
                    ((opcode_i & `INST_SRAI_MASK) == `INST_SRAI)     ||
                    ((opcode_i & `INST_ORI_MASK) == `INST_ORI)       ||
                    ((opcode_i & `INST_ANDI_MASK) == `INST_ANDI)     ||
                    ((opcode_i & `INST_ADD_MASK) == `INST_ADD)       ||
                    ((opcode_i & `INST_SUB_MASK) == `INST_SUB)       ||
                    ((opcode_i & `INST_SLL_MASK) == `INST_SLL)       ||
                    ((opcode_i & `INST_SLT_MASK) == `INST_SLT)       ||
                    ((opcode_i & `INST_SLTU_MASK) == `INST_SLTU)     ||
                    ((opcode_i & `INST_XOR_MASK) == `INST_XOR)       ||
                    ((opcode_i & `INST_SRL_MASK) == `INST_SRL)       ||
                    ((opcode_i & `INST_SRA_MASK) == `INST_SRA)       ||
                    ((opcode_i & `INST_OR_MASK) == `INST_OR)         ||
                    ((opcode_i & `INST_AND_MASK) == `INST_AND)       ||
                    ((opcode_i & `INST_LB_MASK) == `INST_LB)         ||
                    ((opcode_i & `INST_LH_MASK) == `INST_LH)         ||
                    ((opcode_i & `INST_LW_MASK) == `INST_LW)         ||
                    ((opcode_i & `INST_LBU_MASK) == `INST_LBU)       ||
                    ((opcode_i & `INST_LHU_MASK) == `INST_LHU)       ||
                    ((opcode_i & `INST_LWU_MASK) == `INST_LWU)       ||
                    ((opcode_i & `INST_MUL_MASK) == `INST_MUL)       ||
                    ((opcode_i & `INST_MULH_MASK) == `INST_MULH)     ||
                    ((opcode_i & `INST_MULHSU_MASK) == `INST_MULHSU) ||
                    ((opcode_i & `INST_MULHU_MASK) == `INST_MULHU)   ||
                    ((opcode_i & `INST_DIV_MASK) == `INST_DIV)       ||
                    ((opcode_i & `INST_DIVU_MASK) == `INST_DIVU)     ||
                    ((opcode_i & `INST_REM_MASK) == `INST_REM)       ||
                    ((opcode_i & `INST_REMU_MASK) == `INST_REMU)     ||
                    ((opcode_i & `INST_CSRRW_MASK) == `INST_CSRRW)   ||
                    ((opcode_i & `INST_CSRRS_MASK) == `INST_CSRRS)   ||
                    ((opcode_i & `INST_CSRRC_MASK) == `INST_CSRRC)   ||
                    ((opcode_i & `INST_CSRRWI_MASK) == `INST_CSRRWI) ||
                    ((opcode_i & `INST_CSRRSI_MASK) == `INST_CSRRSI) ||
                    ((opcode_i & `INST_CSRRCI_MASK) == `INST_CSRRCI);

assign exec_o =     ((opcode_i & `INST_ANDI_MASK) == `INST_ANDI)  ||
                    ((opcode_i & `INST_ADDI_MASK) == `INST_ADDI)  ||
                    ((opcode_i & `INST_SLTI_MASK) == `INST_SLTI)  ||
                    ((opcode_i & `INST_SLTIU_MASK) == `INST_SLTIU)||
                    ((opcode_i & `INST_ORI_MASK) == `INST_ORI)    ||
                    ((opcode_i & `INST_XORI_MASK) == `INST_XORI)  ||
                    ((opcode_i & `INST_SLLI_MASK) == `INST_SLLI)  ||
                    ((opcode_i & `INST_SRLI_MASK) == `INST_SRLI)  ||
                    ((opcode_i & `INST_SRAI_MASK) == `INST_SRAI)  ||
                    ((opcode_i & `INST_LUI_MASK) == `INST_LUI)    ||
                    ((opcode_i & `INST_AUIPC_MASK) == `INST_AUIPC)||
                    ((opcode_i & `INST_ADD_MASK) == `INST_ADD)    ||
                    ((opcode_i & `INST_SUB_MASK) == `INST_SUB)    ||
                    ((opcode_i & `INST_SLT_MASK) == `INST_SLT)    ||
                    ((opcode_i & `INST_SLTU_MASK) == `INST_SLTU)  ||
                    ((opcode_i & `INST_XOR_MASK) == `INST_XOR)    ||
                    ((opcode_i & `INST_OR_MASK) == `INST_OR)      ||
                    ((opcode_i & `INST_AND_MASK) == `INST_AND)    ||
                    ((opcode_i & `INST_SLL_MASK) == `INST_SLL)    ||
                    ((opcode_i & `INST_SRL_MASK) == `INST_SRL)    ||
                    ((opcode_i & `INST_SRA_MASK) == `INST_SRA);

assign lsu_o =      ((opcode_i & `INST_LB_MASK) == `INST_LB)   ||
                    ((opcode_i & `INST_LH_MASK) == `INST_LH)   ||
                    ((opcode_i & `INST_LW_MASK) == `INST_LW)   ||
                    ((opcode_i & `INST_LBU_MASK) == `INST_LBU) ||
                    ((opcode_i & `INST_LHU_MASK) == `INST_LHU) ||
                    ((opcode_i & `INST_LWU_MASK) == `INST_LWU) ||
                    ((opcode_i & `INST_SB_MASK) == `INST_SB)   ||
                    ((opcode_i & `INST_SH_MASK) == `INST_SH)   ||
                    ((opcode_i & `INST_SW_MASK) == `INST_SW);

assign branch_o =   ((opcode_i & `INST_JAL_MASK) == `INST_JAL)   ||
                    ((opcode_i & `INST_JALR_MASK) == `INST_JALR) ||
                    ((opcode_i & `INST_BEQ_MASK) == `INST_BEQ)   ||
                    ((opcode_i & `INST_BNE_MASK) == `INST_BNE)   ||
                    ((opcode_i & `INST_BLT_MASK) == `INST_BLT)   ||
                    ((opcode_i & `INST_BGE_MASK) == `INST_BGE)   ||
                    ((opcode_i & `INST_BLTU_MASK) == `INST_BLTU) ||
                    ((opcode_i & `INST_BGEU_MASK) == `INST_BGEU);

assign mul_o =      enable_muldiv_i &&
                    (((opcode_i & `INST_MUL_MASK) == `INST_MUL)    ||
                    ((opcode_i & `INST_MULH_MASK) == `INST_MULH)   ||
                    ((opcode_i & `INST_MULHSU_MASK) == `INST_MULHSU) ||
                    ((opcode_i & `INST_MULHU_MASK) == `INST_MULHU));

assign div_o =      enable_muldiv_i &&
                    (((opcode_i & `INST_DIV_MASK) == `INST_DIV) ||
                    ((opcode_i & `INST_DIVU_MASK) == `INST_DIVU) ||
                    ((opcode_i & `INST_REM_MASK) == `INST_REM) ||
                    ((opcode_i & `INST_REMU_MASK) == `INST_REMU));

assign csr_o =      ((opcode_i & `INST_ECALL_MASK) == `INST_ECALL)            ||
                    ((opcode_i & `INST_EBREAK_MASK) == `INST_EBREAK)          ||
                    ((opcode_i & `INST_ERET_MASK) == `INST_ERET)              ||
                    ((opcode_i & `INST_CSRRW_MASK) == `INST_CSRRW)            ||
                    ((opcode_i & `INST_CSRRS_MASK) == `INST_CSRRS)            ||
                    ((opcode_i & `INST_CSRRC_MASK) == `INST_CSRRC)            ||
                    ((opcode_i & `INST_CSRRWI_MASK) == `INST_CSRRWI)          ||
                    ((opcode_i & `INST_CSRRSI_MASK) == `INST_CSRRSI)          ||
                    ((opcode_i & `INST_CSRRCI_MASK) == `INST_CSRRCI)          ||
                    ((opcode_i & `INST_WFI_MASK) == `INST_WFI)                ||
                    ((opcode_i & `INST_FENCE_MASK) == `INST_FENCE)            ||
                    ((opcode_i & `INST_IFENCE_MASK) == `INST_IFENCE)          ||
                    ((opcode_i & `INST_SFENCE_MASK) == `INST_SFENCE)          ||
                    invalid_w || fetch_fault_i;

// Define the `lsu_v_o` flag for vector load/store operations
assign lsu_v_o =    enable_vector_extension_i && 
                    (((opcode_i & `INST_VLE8_V_MASK)  == `INST_VLE8_V)  ||
                    ((opcode_i & `INST_VLE16_V_MASK) == `INST_VLE16_V) ||
                    ((opcode_i & `INST_VLE32_V_MASK) == `INST_VLE32_V) ||
                    ((opcode_i & `INST_VLE64_V_MASK) == `INST_VLE64_V) ||
                    ((opcode_i & `INST_VSE8_V_MASK)  == `INST_VSE8_V)  ||
                    ((opcode_i & `INST_VSE16_V_MASK) == `INST_VSE16_V) ||
                    ((opcode_i & `INST_VSE32_V_MASK) == `INST_VSE32_V) ||
                    ((opcode_i & `INST_VSE64_V_MASK) == `INST_VSE64_V));

// Define the `alu_v_o` flag for vector arithmetic operations
assign alu_v_o =    enable_vector_extension_i && 
                    (((opcode_i & `INST_VADD_VI_MASK) == `INST_VADD_VI)   ||
                    ((opcode_i & `INST_VADD_VV_MASK) == `INST_VADD_VV) ||
                    ((opcode_i & `INST_VADD_VX_MASK) == `INST_VADD_VX) ||
                    ((opcode_i & `INST_VMV_V_X_MASK) == `INST_VMV_V_X) ||
                    ((opcode_i & `INST_VSUB_VV_MASK) == `INST_VSUB_VV) ||
                    ((opcode_i & `INST_VSUB_VX_MASK) == `INST_VSUB_VX)   ||
                    ((opcode_i & `INST_VRSUB_VI_MASK) == `INST_VRSUB_VI) ||
                    ((opcode_i & `INST_VRSUB_VX_MASK) == `INST_VRSUB_VX) ||
                    ((opcode_i & `INST_VMINU_VV_MASK) == `INST_VMINU_VV) ||
                    ((opcode_i & `INST_VMINU_VX_MASK) == `INST_VMINU_VX)   ||
                    ((opcode_i & `INST_VMAXU_VV_MASK) == `INST_VMAXU_VV) ||
                    ((opcode_i & `INST_VMAXU_VX_MASK) == `INST_VMAXU_VX) ||
                    ((opcode_i & `INST_VMUL_VV_MASK) == `INST_VMUL_VV)   ||
                    ((opcode_i & `INST_VREDSUM_VS_MASK) == `INST_VREDSUM_VS));

endmodule
