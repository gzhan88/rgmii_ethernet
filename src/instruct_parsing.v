`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:             Xunitek
// Engineer:            Devin
// Email:               Devin.song@xunitek.com      	     
// Module Name:         servo_encoder_signal_process
// HDL Type:            Verilog HDL 
// Target Devices:      zynq-xc7z020clg484-1
// Tool versions:       vivado 2019.1 
// Description:         
// Create Date: 
// Dependencies: 
//--------------------------------------------------------------------------------
// Revision History 		                         
//
//--------------------------------------------------------------------------------
// Additional Comments: 
//protocal data header description:(16 bytes)
//byte          description          type           unit     value
// 4            pkg_length           uint_32        byte 
// 4            pkg_cnt              uint_32        num
// 4            reserved             uint_32        num
// 4            instruct_ID          uint_32        num
//
//instruct_ID:
//  1:connect request
//  2:disconnect request
//100:platform DOF command mode data
//101:actuator position command mode data
//102:motion cueing mode data
//103:playback mode data
//104:extended motion cueing mode data
//105:actuator position,velocity,acceleration command mode data
// 
//////////////////////////////////////////////////////////////////////////////////
module instruct_parsing#(parameter INS_WIDTH = 32)
        (
            input                   i_sys_clk,
            input                   i_rst_n,

            input                   i_udp_data_receive_done,
            input [INS_WIDTH-1:0]   i_instruct_data,
            output [15:0]           o_udp_data_rd_addr,
            
            output                  o_dof_data_en,  
            output [INS_WIDTH-1:0]  o_dof_data,            
            output                  o_act_pos_data_en,                
            output [INS_WIDTH-1:0]  o_act_pos_data,                   
            output                  o_mot_cue_data_en,                
            output [INS_WIDTH-1:0]  o_mot_cue_data,                   
            output                  o_playback_data_en,               
            output [INS_WIDTH-1:0]  o_playback_data,                  
            output                  o_ext_mot_cue_data_en,            
            output [INS_WIDTH-1:0]  o_ext_mot_cue_data,               
            output                  o_act_pva_data_en,                
            output [INS_WIDTH-1:0]  o_act_pva_data                   
            
            
            
 
        );

localparam          Idle                                            = 4'd0 ;
localparam          Start_Parse_Instruct                            = 4'd1 ;
localparam          Split_Instruct_Header                           = 4'd2 ;
localparam          Pkg_Sequence_Cnt                                = 4'd3 ;
localparam          Judge_Instruct_Type                             = 4'd4 ;
localparam          Start_Seperate_DOF_Data                         = 4'd5 ;//100
localparam          Start_Seperate_Actuator_Position_Data           = 4'd6 ;//101
localparam          Start_Seperate_Motion_Cueing_Data               = 4'd7 ;//102
localparam          Start_Seperate_Playback_Data                    = 4'd8 ;//103
localparam          Start_Seperate_Extend_Motion_Cueing_Data        = 4'd9 ;//104
localparam          Start_Seperate_Actuator_PVA_Data                = 4'd10;//105

localparam          HEADER_LENGTH               =  4; 
parameter           DOF_WORD_NUM                =  9;
parameter           ACTUATOR_POSITION_WORD_NUM  =  9; 
parameter           MOTION_CUEING_WORD_NUM      =  16;
parameter           PLAYBACK_WORD_NUM           =  2;
parameter           EXT_MOTION_CUEING_WORD_NUM  =  17;
parameter           ACTURATOR_PVA_WORD_NUM      =  21;
reg [3:0]           s_fsm_cur;
reg [3:0]           s_fsm_next;
reg [7:0]           s_instruct_cnt;
reg [7:0]           s_param_cnt;
reg [INS_WIDTH-1:0] s_instruct_pkg_length;
reg [INS_WIDTH-1:0] s_instruct_pkg_cnt;
reg [INS_WIDTH-1:0] s_instruct_ID;
reg                 s_split_instruct_header_done;
reg                 s_ID_is_connect_req;
reg                 s_ID_is_disconnect_req;
reg                 s_ID_is_DOF_mode;
reg                 s_ID_is_actuator_postion_mode;
reg                 s_ID_is_motion_cueing_mode;
reg                 s_ID_is_playback_mode;
reg                 s_ID_is_extend_motion_cueing_mode;
reg                 s_ID_is_actuator_pva_mode;
reg [15:0]          s_udp_data_rd_addr;
reg                 s_connect_ok;
reg                 s_seperate_data_done;
reg                 s_seperate_data_valid;
reg                 s_dof_data_valid;
reg                 s_actuator_postion_data_valid; 
reg                 s_motion_cueing_data_valid;    
reg                 s_playback_data_valid;         
reg                 s_ext_motion_cueing_data_valid;
reg                 s_actuator_pva_data_valid;     
reg [INS_WIDTH-1:0] s_instruct_data;
reg [INS_WIDTH-1:0] s_pkg_missing_frame;
reg [INS_WIDTH-1:0] s_former_pkg_seq_cnt;
reg                 s_pkg_missing_frame_valid;

always@(posedge i_sys_clk or negedge i_rst_n)begin
    if(!i_rst_n)begin
        s_fsm_cur   <= Idle;
    end else begin
        s_fsm_cur   <= s_fsm_next;
    end
end                            
  
always@(*)begin
    case(s_fsm_cur)
        Idle:
            begin
                if(i_udp_data_receive_done)begin
                    s_fsm_next <= Start_Parse_Instruct;
                end else begin
                    s_fsm_next <= Idle;
                end
            end
        Start_Parse_Instruct:
            begin
                s_fsm_next <= Split_Instruct_Header;
            end
        Split_Instruct_Header:
            begin
                if(s_split_instruct_header_done)begin
                    s_fsm_next <= Pkg_Sequence_Cnt;
                end else begin
                    s_fsm_next <= Split_Instruct_Header;
                end
            end
        Pkg_Sequence_Cnt:
            begin
                s_fsm_next <= Judge_Instruct_Type;
            end
        Judge_Instruct_Type:
            begin
                if(s_ID_is_connect_req)begin
                    s_fsm_next <= Idle;
                end else if(s_ID_is_disconnect_req)begin
                    s_fsm_next <= Idle;
                end else if(s_ID_is_DOF_mode)begin
                    s_fsm_next <= Start_Seperate_DOF_Data;
                end else if(s_ID_is_actuator_postion_mode)begin
                    s_fsm_next <= Start_Seperate_Actuator_Position_Data;
                end else if(s_ID_is_motion_cueing_mode)begin
                    s_fsm_next <= Start_Seperate_Motion_Cueing_Data;
                end else if(s_ID_is_playback_mode)begin
                    s_fsm_next <= Start_Seperate_Playback_Data;
                end else if(s_ID_is_extend_motion_cueing_mode)begin
                    s_fsm_next <= Start_Seperate_Extend_Motion_Cueing_Data;
                end else if(s_ID_is_actuator_pva_mode)begin
                    s_fsm_next <= Start_Seperate_Actuator_PVA_Data;
                end else begin
                    s_fsm_next <= Judge_Instruct_Type;
                end
            end
        Start_Seperate_DOF_Data:
            begin
                if(s_seperate_data_done)begin
                    s_fsm_next <= Idle;
                end else begin
                    s_fsm_next <= Start_Seperate_DOF_Data;
                end
            end
        Start_Seperate_Actuator_Position_Data:
            begin
                if(s_seperate_data_done)begin
                    s_fsm_next <= Idle;
                end else begin
                    s_fsm_next <= Start_Seperate_Actuator_Position_Data;
                end   
            end
        Start_Seperate_Motion_Cueing_Data:
            begin
                if(s_seperate_data_done)begin
                    s_fsm_next <= Idle;
                end else begin
                    s_fsm_next <= Start_Seperate_Motion_Cueing_Data;
                end 
            end
        Start_Seperate_Playback_Data:
            begin
                if(s_seperate_data_done)begin
                    s_fsm_next <= Idle;
                end else begin
                    s_fsm_next <= Start_Seperate_Playback_Data;
                end 
            end
        Start_Seperate_Extend_Motion_Cueing_Data:
            begin
                if(s_seperate_data_done)begin
                    s_fsm_next <= Idle;
                end else begin
                    s_fsm_next <= Start_Seperate_Extend_Motion_Cueing_Data;
                end 
            end
        Start_Seperate_Actuator_PVA_Data:
            begin
                if(s_seperate_data_done)begin
                    s_fsm_next <= Idle;
                end else begin
                    s_fsm_next <= Start_Seperate_Actuator_PVA_Data;
                end 
            end
        default:   s_fsm_next <= Idle;
    endcase
end    
            
                                       
always@(posedge i_sys_clk or negedge i_rst_n)begin
    if(!i_rst_n)begin
        s_udp_data_rd_addr <= 'd0;
        s_instruct_cnt     <= 'd0;
        s_param_cnt        <= 'd0;
        s_seperate_data_done <= 1'b0; 
    end else begin
        case(s_fsm_next)
            Split_Instruct_Header:
                begin
                    if(s_udp_data_rd_addr==HEADER_LENGTH-1)begin
                        s_udp_data_rd_addr <= s_udp_data_rd_addr;
                    end else begin
                        s_udp_data_rd_addr <= s_udp_data_rd_addr + 1'b1;
                    end 
                    s_instruct_cnt     <= s_instruct_cnt + 1'b1;
                end
            Judge_Instruct_Type:
                begin
                    s_udp_data_rd_addr <= s_udp_data_rd_addr;
                    s_instruct_cnt     <= 'd0;
                    s_param_cnt        <= 'd0;
                end
            Start_Seperate_DOF_Data:
                begin
                    if(s_udp_data_rd_addr==HEADER_LENGTH+DOF_WORD_NUM-1)begin
                        s_udp_data_rd_addr <= s_udp_data_rd_addr;
                    end else begin
                        s_udp_data_rd_addr <= s_udp_data_rd_addr + 1'b1;
                    end
                    s_param_cnt        <= s_param_cnt+1'b1;
                    
                    if(s_param_cnt==DOF_WORD_NUM)begin
                        s_seperate_data_done <= 1'b1;
                    end else begin
                        s_seperate_data_done <= 1'b0; 
                    end
                end
            Start_Seperate_Actuator_Position_Data:
                begin
                    if(s_udp_data_rd_addr==HEADER_LENGTH+ACTUATOR_POSITION_WORD_NUM-1)begin
                        s_udp_data_rd_addr <= s_udp_data_rd_addr;
                    end else begin
                        s_udp_data_rd_addr <= s_udp_data_rd_addr + 1'b1;
                    end
                    s_param_cnt        <= s_param_cnt+1'b1;
                    
                    if(s_param_cnt==ACTUATOR_POSITION_WORD_NUM)begin
                        s_seperate_data_done <= 1'b1;
                    end else begin
                        s_seperate_data_done <= 1'b0; 
                    end
                end
            Start_Seperate_Motion_Cueing_Data:
                begin
                    if(s_udp_data_rd_addr==HEADER_LENGTH+MOTION_CUEING_WORD_NUM-1)begin
                        s_udp_data_rd_addr <= s_udp_data_rd_addr;
                    end else begin
                        s_udp_data_rd_addr <= s_udp_data_rd_addr + 1'b1;
                    end
                    s_param_cnt        <= s_param_cnt+1'b1;
                    
                    if(s_param_cnt==MOTION_CUEING_WORD_NUM)begin
                        s_seperate_data_done <= 1'b1;
                    end else begin
                        s_seperate_data_done <= 1'b0; 
                    end
                end
            Start_Seperate_Playback_Data:
                begin
                    if(s_udp_data_rd_addr==HEADER_LENGTH+PLAYBACK_WORD_NUM-1)begin
                        s_udp_data_rd_addr <= s_udp_data_rd_addr;
                    end else begin
                        s_udp_data_rd_addr <= s_udp_data_rd_addr + 1'b1;
                    end
                    s_param_cnt        <= s_param_cnt+1'b1;
                    
                    if(s_param_cnt==PLAYBACK_WORD_NUM)begin
                        s_seperate_data_done <= 1'b1;
                    end else begin
                        s_seperate_data_done <= 1'b0; 
                    end
                end 
            Start_Seperate_Extend_Motion_Cueing_Data:
                begin
                    if(s_udp_data_rd_addr==HEADER_LENGTH+EXT_MOTION_CUEING_WORD_NUM-1)begin
                        s_udp_data_rd_addr <= s_udp_data_rd_addr;
                    end else begin
                        s_udp_data_rd_addr <= s_udp_data_rd_addr + 1'b1;
                    end
                    s_param_cnt        <= s_param_cnt+1'b1;
                    
                    if(s_param_cnt==EXT_MOTION_CUEING_WORD_NUM)begin
                        s_seperate_data_done <= 1'b1;
                    end else begin
                        s_seperate_data_done <= 1'b0; 
                    end
                end                 
            Start_Seperate_Actuator_PVA_Data:
                begin
                    if(s_udp_data_rd_addr==HEADER_LENGTH+ACTURATOR_PVA_WORD_NUM-1)begin
                        s_udp_data_rd_addr <= s_udp_data_rd_addr;
                    end else begin
                        s_udp_data_rd_addr <= s_udp_data_rd_addr + 1'b1;
                    end
                    s_param_cnt        <= s_param_cnt+1'b1;
                    
                    if(s_param_cnt==ACTURATOR_PVA_WORD_NUM)begin
                        s_seperate_data_done <= 1'b1;
                    end else begin
                        s_seperate_data_done <= 1'b0; 
                    end
                end            
            default:
                begin
                    s_udp_data_rd_addr      <=  'd0;
                    s_instruct_cnt          <=  'd0;
                    s_param_cnt             <=  'd0;
                    s_seperate_data_done    <= 1'b0; 
                end
        endcase
    end
end

      
assign o_udp_data_rd_addr =  s_udp_data_rd_addr;
always@(posedge i_sys_clk or negedge i_rst_n)begin
    if(!i_rst_n)begin
        s_split_instruct_header_done    <= 1'b0; 
    end else if(s_instruct_cnt==HEADER_LENGTH)begin
        s_split_instruct_header_done    <= 1'b1;
    end else begin
        s_split_instruct_header_done    <= 1'b0; 
    end
end    

always@(posedge i_sys_clk or negedge i_rst_n)begin
    if(!i_rst_n)begin
        s_pkg_missing_frame <= 'd0;
        s_pkg_missing_frame_valid <= 1'b0;
        s_former_pkg_seq_cnt      <= 'd0;
    end else if(s_fsm_next==Pkg_Sequence_Cnt)begin
        if(s_former_pkg_seq_cnt+1==s_instruct_pkg_cnt)begin
            s_pkg_missing_frame <= 'd0;
            s_pkg_missing_frame_valid <= 1'b0;
        end else begin
            s_pkg_missing_frame <= s_instruct_pkg_cnt - s_former_pkg_seq_cnt-1'b1;
            s_pkg_missing_frame_valid <= 1'b1;
        end
        s_former_pkg_seq_cnt <= s_instruct_pkg_cnt;
    end else begin
        s_pkg_missing_frame <= s_pkg_missing_frame;
        s_pkg_missing_frame_valid <= 1'b0;
        s_former_pkg_seq_cnt      <= s_former_pkg_seq_cnt;
    end
end 

always@(posedge i_sys_clk or negedge i_rst_n)begin
    if(!i_rst_n)begin
        s_seperate_data_valid    <= 1'b0; 
    end else begin
        case(s_fsm_next)
            Start_Seperate_DOF_Data,                         
            Start_Seperate_Actuator_Position_Data,           
            Start_Seperate_Motion_Cueing_Data,               
            Start_Seperate_Playback_Data,                    
            Start_Seperate_Extend_Motion_Cueing_Data,        
            Start_Seperate_Actuator_PVA_Data:                
                begin
                    if(s_param_cnt=='d1)begin
                        s_seperate_data_valid <= 1'b1;
                    end else begin
                        s_seperate_data_valid <= s_seperate_data_valid;
                    end
                end                
            default:    s_seperate_data_valid <= 1'b0; 
        endcase
    end
end
always@(posedge i_sys_clk or negedge i_rst_n)begin
    if(!i_rst_n)begin
        s_dof_data_valid                <= 1'b0;
        s_actuator_postion_data_valid   <= 1'b0;
        s_motion_cueing_data_valid      <= 1'b0;
        s_playback_data_valid           <= 1'b0;
        s_ext_motion_cueing_data_valid  <= 1'b0;
        s_actuator_pva_data_valid       <= 1'b0;
        s_instruct_data                 <=  'd0;
    end else begin
        case(s_fsm_cur)
            Start_Seperate_DOF_Data:
                s_dof_data_valid                <= s_seperate_data_valid;
            Start_Seperate_Actuator_Position_Data:
                s_actuator_postion_data_valid   <= s_seperate_data_valid;
            Start_Seperate_Motion_Cueing_Data:
                s_motion_cueing_data_valid      <= s_seperate_data_valid;
            Start_Seperate_Playback_Data:
                s_playback_data_valid           <= s_seperate_data_valid;
            Start_Seperate_Extend_Motion_Cueing_Data:
                s_ext_motion_cueing_data_valid  <= s_seperate_data_valid; 
            Start_Seperate_Actuator_PVA_Data:
                s_actuator_pva_data_valid       <= s_seperate_data_valid; 
            default:
                begin
                    s_dof_data_valid                <= 1'b0;
                    s_actuator_postion_data_valid   <= 1'b0;
                    s_motion_cueing_data_valid      <= 1'b0;
                    s_playback_data_valid           <= 1'b0;
                    s_ext_motion_cueing_data_valid  <= 1'b0;
                    s_actuator_pva_data_valid       <= 1'b0;
                end
        endcase   
        s_instruct_data         <= i_instruct_data;
    end
end
assign o_dof_data_en            = s_dof_data_valid;
assign o_dof_data               = s_instruct_data;
assign o_act_pos_data_en        = s_actuator_postion_data_valid;
assign o_act_pos_data           = s_instruct_data;
assign o_mot_cue_data_en        = s_motion_cueing_data_valid;
assign o_mot_cue_data           = s_instruct_data;
assign o_playback_data_en       = s_playback_data_valid;
assign o_playback_data          = s_instruct_data;
assign o_ext_mot_cue_data_en    = s_ext_motion_cueing_data_valid;
assign o_ext_mot_cue_data       = s_instruct_data;
assign o_act_pva_data_en        = s_actuator_pva_data_valid;
assign o_act_pva_data           = s_instruct_data;

always@(posedge i_sys_clk or negedge i_rst_n)begin
    if(!i_rst_n)begin
                    s_ID_is_connect_req                 <= 1'b0;
                    s_ID_is_disconnect_req              <= 1'b0;
                    s_ID_is_DOF_mode                    <= 1'b0;
                    s_ID_is_actuator_postion_mode       <= 1'b0;
                    s_ID_is_motion_cueing_mode          <= 1'b0;
                    s_ID_is_playback_mode               <= 1'b0;
                    s_ID_is_extend_motion_cueing_mode   <= 1'b0;
                    s_ID_is_actuator_pva_mode           <= 1'b0;
    end else if(s_fsm_cur==Pkg_Sequence_Cnt)begin
        case(s_instruct_ID[7:0])
            8'd1:
                begin
                    s_ID_is_connect_req             <= 1'b1;
                end
            8'd2:
                begin
                    s_ID_is_disconnect_req          <= 1'b1;
                end
            8'd100:
                begin
                    if(s_connect_ok)begin
                        s_ID_is_DOF_mode                <= 1'b1;
                    end else begin
                        s_ID_is_DOF_mode                <= 1'b0;
                    end
                end
            8'd101:
                begin
                    if(s_connect_ok)begin
                        s_ID_is_actuator_postion_mode            <= 1'b1;
                    end else begin
                        s_ID_is_actuator_postion_mode            <= 1'b0;
                    end
                end
            8'd102:
                begin
                    if(s_connect_ok)begin

                        s_ID_is_motion_cueing_mode             <= 1'b1;
                    end else begin
                        s_ID_is_motion_cueing_mode             <= 1'b0;
                    end
                end   
            8'd103:
                begin
                    if(s_connect_ok)begin
                        s_ID_is_playback_mode           <= 1'b1;
                    end else begin
                        s_ID_is_playback_mode           <= 1'b0;
                    end
                end  
            8'd104:
                begin
                    if(s_connect_ok)begin
                        s_ID_is_extend_motion_cueing_mode      <= 1'b1;
                    end else begin
                        s_ID_is_extend_motion_cueing_mode      <= 1'b0;
                    end
                end                  
            8'd105:
                begin
                    if(s_connect_ok)begin
                        s_ID_is_actuator_pva_mode      <= 1'b1;
                    end else begin
                        s_ID_is_actuator_pva_mode      <= 1'b0;
                    end
                end 
            default:
                begin
                    s_ID_is_connect_req                 <= 1'b0;
                    s_ID_is_disconnect_req              <= 1'b0;
                    s_ID_is_DOF_mode                    <= 1'b0;
                    s_ID_is_actuator_postion_mode       <= 1'b0;
                    s_ID_is_motion_cueing_mode          <= 1'b0;
                    s_ID_is_playback_mode               <= 1'b0;
                    s_ID_is_extend_motion_cueing_mode   <= 1'b0;
                    s_ID_is_actuator_pva_mode           <= 1'b0;
                end
        endcase
    end else begin
        s_ID_is_connect_req                 <= 1'b0;
        s_ID_is_disconnect_req              <= 1'b0;
        s_ID_is_DOF_mode                    <= 1'b0;
        s_ID_is_actuator_postion_mode       <= 1'b0;
        s_ID_is_motion_cueing_mode          <= 1'b0;
        s_ID_is_playback_mode               <= 1'b0;
        s_ID_is_extend_motion_cueing_mode   <= 1'b0;
        s_ID_is_actuator_pva_mode           <= 1'b0;
    end
end

always@(posedge i_sys_clk or negedge i_rst_n)begin
    if(!i_rst_n)begin
        s_connect_ok <= 1'b0;
    end else if(s_ID_is_connect_req)begin
        s_connect_ok <= 1'b1;
    end else if(s_ID_is_disconnect_req)begin
        s_connect_ok <= 1'b0;
    end else begin
        s_connect_ok <= s_connect_ok;
    end
end

always@(posedge i_sys_clk or negedge i_rst_n)begin
    if(!i_rst_n)begin
        s_instruct_pkg_length <= 'd0; 
        s_instruct_pkg_cnt    <= 'd0;
        s_instruct_ID         <= 'd0;  
    end else begin
        case(s_instruct_cnt)
            'd1:
                begin
                    s_instruct_pkg_length <= i_instruct_data;
                end
            'd2:
                begin
                    s_instruct_pkg_cnt    <= i_instruct_data;
                end
            'd4:
                begin
                    s_instruct_ID         <= i_instruct_data;
                end
            default:
                begin
                    s_instruct_pkg_length <= s_instruct_pkg_length; 
                    s_instruct_pkg_cnt    <= s_instruct_pkg_cnt;
                    s_instruct_ID         <= s_instruct_ID;
                end
        endcase
    end 
end

endmodule