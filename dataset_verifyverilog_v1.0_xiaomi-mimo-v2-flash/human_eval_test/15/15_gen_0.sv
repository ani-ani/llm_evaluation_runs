module string_generator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [7:0] char_0,
    output reg [7:0] char_1,
    output reg [7:0] char_2,
    output reg [7:0] char_3,
    output reg [7:0] char_4,
    output reg [7:0] char_5,
    output reg [7:0] char_6,
    output reg [7:0] char_7,
    output reg [7:0] char_8,
    output reg [7:0] char_9,
    output reg [7:0] char_10,
    output reg [7:0] char_11,
    output reg [7:0] char_12,
    output reg [7:0] char_13,
    output reg [7:0] char_14,
    output reg [7:0] char_15,
    output reg [7:0] char_16,
    output reg [7:0] char_17,
    output reg [7:0] char_18,
    output reg [7:0] char_19,
    output reg [7:0] char_20,
    output reg [7:0] char_21,
    output reg [7:0] char_22,
    output reg [7:0] char_23,
    output reg [7:0] char_24,
    output reg [7:0] char_25,
    output reg [7:0] char_26,
    output reg [7:0] char_27,
    output reg [7:0] char_28,
    output reg [7:0] char_29,
    output reg [7:0] char_30,
    output reg [7:0] char_31,
    output reg [7:0] char_32,
    output reg [7:0] char_33,
    output reg [7:0] char_34,
    output reg [7:0] char_35,
    output reg [7:0] char_36,
    output reg [7:0] char_37,
    output reg [7:0] char_38,
    output reg [7:0] char_39,
    output reg [7:0] char_40,
    output reg [7:0] char_41,
    output reg [7:0] char_42,
    output reg [7:0] char_43,
    output reg [7:0] char_44,
    output reg [7:0] char_45,
    output reg [7:0] char_46,
    output reg [7:0] char_47,
    output reg [7:0] char_48,
    output reg [7:0] char_49,
    output reg [7:0] char_50,
    output reg [7:0] char_51,
    output reg [7:0] char_52,
    output reg [7:0] char_53,
    output reg [7:0] char_54,
    output reg [7:0] char_55,
    output reg [7:0] char_56,
    output reg [7:0] char_57,
    output reg [7:0] char_58,
    output reg [7:0] char_59,
    output reg [7:0] char_60,
    output reg [7:0] char_61,
    output reg [7:0] char_62,
    output reg [7:0] char_63,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] GENERATING = 2'd1;
    localparam [1:0] COMPLETE   = 2'd2;

    reg [1:0] state;
    reg [3:0] current_num;
    reg [6:0] char_idx;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // ASCII constants
    localparam [7:0] ASCII_SPACE = 8'd32;
    localparam [7:0] ASCII_0 = 8'd48;
    localparam [7:0] ASCII_NULL = 8'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_num <= 4'd0;
            char_idx <= 7'd0;
            cycle_counter <= 8'd0;
            done <= 1'b0;
            char_0 <= ASCII_NULL; char_1 <= ASCII_NULL; char_2 <= ASCII_NULL; char_3 <= ASCII_NULL;
            char_4 <= ASCII_NULL; char_5 <= ASCII_NULL; char_6 <= ASCII_NULL; char_7 <= ASCII_NULL;
            char_8 <= ASCII_NULL; char_9 <= ASCII_NULL; char_10 <= ASCII_NULL; char_11 <= ASCII_NULL;
            char_12 <= ASCII_NULL; char_13 <= ASCII_NULL; char_14 <= ASCII_NULL; char_15 <= ASCII_NULL;
            char_16 <= ASCII_NULL; char_17 <= ASCII_NULL; char_18 <= ASCII_NULL; char_19 <= ASCII_NULL;
            char_20 <= ASCII_NULL; char_21 <= ASCII_NULL; char_22 <= ASCII_NULL; char_23 <= ASCII_NULL;
            char_24 <= ASCII_NULL; char_25 <= ASCII_NULL; char_26 <= ASCII_NULL; char_27 <= ASCII_NULL;
            char_28 <= ASCII_NULL; char_29 <= ASCII_NULL; char_30 <= ASCII_NULL; char_31 <= ASCII_NULL;
            char_32 <= ASCII_NULL; char_33 <= ASCII_NULL; char_34 <= ASCII_NULL; char_35 <= ASCII_NULL;
            char_36 <= ASCII_NULL; char_37 <= ASCII_NULL; char_38 <= ASCII_NULL; char_39 <= ASCII_NULL;
            char_40 <= ASCII_NULL; char_41 <= ASCII_NULL; char_42 <= ASCII_NULL; char_43 <= ASCII_NULL;
            char_44 <= ASCII_NULL; char_45 <= ASCII_NULL; char_46 <= ASCII_NULL; char_47 <= ASCII_NULL;
            char_48 <= ASCII_NULL; char_49 <= ASCII_NULL; char_50 <= ASCII_NULL; char_51 <= ASCII_NULL;
            char_52 <= ASCII_NULL; char_53 <= ASCII_NULL; char_54 <= ASCII_NULL; char_55 <= ASCII_NULL;
            char_56 <= ASCII_NULL; char_57 <= ASCII_NULL; char_58 <= ASCII_NULL; char_59 <= ASCII_NULL;
            char_60 <= ASCII_NULL; char_61 <= ASCII_NULL; char_62 <= ASCII_NULL; char_63 <= ASCII_NULL;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        state <= GENERATING;
                        current_num <= 4'd0;
                        char_idx <= 7'd0;
                    end
                end

                GENERATING: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Generate character for current_num
                    if (current_num <= n) begin
                        if (char_idx < 7'd64) begin
                            case (char_idx)
                                7'd0:   char_0   <= (ASCII_0 + current_num);
                                7'd1:   char_1   <= (ASCII_0 + current_num);
                                7'd2:   char_2   <= (ASCII_0 + current_num);
                                7'd3:   char_3   <= (ASCII_0 + current_num);
                                7'd4:   char_4   <= (ASCII_0 + current_num);
                                7'd5:   char_5   <= (ASCII_0 + current_num);
                                7'd6:   char_6   <= (ASCII_0 + current_num);
                                7'd7:   char_7   <= (ASCII_0 + current_num);
                                7'd8:   char_8   <= (ASCII_0 + current_num);
                                7'd9:   char_9   <= (ASCII_0 + current_num);
                                7'd10:  char_10  <= (ASCII_0 + current_num);
                                7'd11:  char_11  <= (ASCII_0 + current_num);
                                7'd12:  char_12  <= (ASCII_0 + current_num);
                                7'd13:  char_13  <= (ASCII_0 + current_num);
                                7'd14:  char_14  <= (ASCII_0 + current_num);
                                7'd15:  char_15  <= (ASCII_0 + current_num);
                                7'd16:  char_16  <= (ASCII_0 + current_num);
                                7'd17:  char_17  <= (ASCII_0 + current_num);
                                7'd18:  char_18  <= (ASCII_0 + current_num);
                                7'd19:  char_19  <= (ASCII_0 + current_num);
                                7'd20:  char_20  <= (ASCII_0 + current_num);
                                7'd21:  char_21  <= (ASCII_0 + current_num);
                                7'd22:  char_22  <= (ASCII_0 + current_num);
                                7'd23:  char_23  <= (ASCII_0 + current_num);
                                7'd24:  char_24  <= (ASCII_0 + current_num);
                                7'd25:  char_25  <= (ASCII_0 + current_num);
                                7'd26:  char_26  <= (ASCII_0 + current_num);
                                7'd27:  char_27  <= (ASCII_0 + current_num);
                                7'd28:  char_28  <= (ASCII_0 + current_num);
                                7'd29:  char_29  <= (ASCII_0 + current_num);
                                7'd30:  char_30  <= (ASCII_0 + current_num);
                                7'd31:  char_31  <= (ASCII_0 + current_num);
                                7'd32:  char_32  <= (ASCII_0 + current_num);
                                7'd33:  char_33  <= (ASCII_0 + current_num);
                                7'd34:  char_34  <= (ASCII_0 + current_num);
                                7'd35:  char_35  <= (ASCII_0 + current_num);
                                7'd36:  char_36  <= (ASCII_0 + current_num);
                                7'd37:  char_37  <= (ASCII_0 + current_num);
                                7'd38:  char_38  <= (ASCII_0 + current_num);
                                7'd39:  char_39  <= (ASCII_0 + current_num);
                                7'd40:  char_40  <= (ASCII_0 + current_num);
                                7'd41:  char_41  <= (ASCII_0 + current_num);
                                7'd42:  char_42  <= (ASCII_0 + current_num);
                                7'd43:  char_43  <= (ASCII_0 + current_num);
                                7'd44:  char_44  <= (ASCII_0 + current_num);
                                7'd45:  char_45  <= (ASCII_0 + current_num);
                                7'd46:  char_46  <= (ASCII_0 + current_num);
                                7'd47:  char_47  <= (ASCII_0 + current_num);
                                7'd48:  char_48  <= (ASCII_0 + current_num);
                                7'd49:  char_49  <= (ASCII_0 + current_num);
                                7'd50:  char_50  <= (ASCII_0 + current_num);
                                7'd51:  char_51  <= (ASCII_0 + current_num);
                                7'd52:  char_52  <= (ASCII_0 + current_num);
                                7'd53:  char_53  <= (ASCII_0 + current_num);
                                7'd54:  char_54  <= (ASCII_0 + current_num);
                                7'd55:  char_55  <= (ASCII_0 + current_num);
                                7'd56:  char_56  <= (ASCII_0 + current_num);
                                7'd57:  char_57  <= (ASCII_0 + current_num);
                                7'd58:  char_58  <= (ASCII_0 + current_num);
                                7'd59:  char_59  <= (ASCII_0 + current_num);
                                7'd60:  char_60  <= (ASCII_0 + current_num);
                                7'd61:  char_61  <= (ASCII_0 + current_num);
                                7'd62:  char_62  <= (ASCII_0 + current_num);
                                7'd63:  char_63  <= (ASCII_0 + current_num);
                                default: begin end
                            endcase
                            char_idx <= char_idx + 7'd1;
                            
                            // Add space if not last number
                            if (current_num < n) begin
                                if (char_idx < 7'd63) begin
                                    case (char_idx + 7'd1)
                                        7'd0:   char_0   <= ASCII_SPACE;
                                        7'd1:   char_1   <= ASCII_SPACE;
                                        7'd2:   char_2   <= ASCII_SPACE;
                                        7'd3:   char_3   <= ASCII_SPACE;
                                        7'd4:   char_4   <= ASCII_SPACE;
                                        7'd5:   char_5   <= ASCII_SPACE;
                                        7'd6:   char_6   <= ASCII_SPACE;
                                        7'd7:   char_7   <= ASCII_SPACE;
                                        7'd8:   char_8   <= ASCII_SPACE;
                                        7'd9:   char_9   <= ASCII_SPACE;
                                        7'd10:  char_10  <= ASCII_SPACE;
                                        7'd11:  char_11  <= ASCII_SPACE;
                                        7'd12:  char_12  <= ASCII_SPACE;
                                        7'd13:  char_13  <= ASCII_SPACE;
                                        7'd14:  char_14  <= ASCII_SPACE;
                                        7'd15:  char_15  <= ASCII_SPACE;
                                        7'd16:  char_16  <= ASCII_SPACE;
                                        7'd17:  char_17  <= ASCII_SPACE;
                                        7'd18:  char_18  <= ASCII_SPACE;
                                        7'd19:  char_19  <= ASCII_SPACE;
                                        7'd20:  char_20  <= ASCII_SPACE;
                                        7'd21:  char_21  <= ASCII_SPACE;
                                        7'd22:  char_22  <= ASCII_SPACE;
                                        7'd23:  char_23  <= ASCII_SPACE;
                                        7'd24:  char_24  <= ASCII_SPACE;
                                        7'd25:  char_25  <= ASCII_SPACE;
                                        7'd26:  char_26  <= ASCII_SPACE;
                                        7'd27:  char_27  <= ASCII_SPACE;
                                        7'd28:  char_28  <= ASCII_SPACE;
                                        7'd29:  char_29  <= ASCII_SPACE;
                                        7'd30:  char_30  <= ASCII_SPACE;
                                        7'd31:  char_31  <= ASCII_SPACE;
                                        7'd32:  char_32  <= ASCII_SPACE;
                                        7'd33:  char_33  <= ASCII_SPACE;
                                        7'd34:  char_34  <= ASCII_SPACE;
                                        7'd35:  char_35  <= ASCII_SPACE;
                                        7'd36:  char_36  <= ASCII_SPACE;
                                        7'd37:  char_37  <= ASCII_SPACE;
                                        7'd38:  char_38  <= ASCII_SPACE;
                                        7'd39:  char_39  <= ASCII_SPACE;
                                        7'd40:  char_40  <= ASCII_SPACE;
                                        7'd41:  char_41  <= ASCII_SPACE;
                                        7'd42:  char_42  <= ASCII_SPACE;
                                        7'd43:  char_43  <= ASCII_SPACE;
                                        7'd44:  char_44  <= ASCII_SPACE;
                                        7'd45:  char_45  <= ASCII_SPACE;
                                        7'd46:  char_46  <= ASCII_SPACE;
                                        7'd47:  char_47  <= ASCII_SPACE;
                                        7'd48:  char_48  <= ASCII_SPACE;
                                        7'd49:  char_49  <= ASCII_SPACE;
                                        7'd50:  char_50  <= ASCII_SPACE;
                                        7'd51:  char_51  <= ASCII_SPACE;
                                        7'd52:  char_52  <= ASCII_SPACE;
                                        7'd53:  char_53  <= ASCII_SPACE;
                                        7'd54:  char_54  <= ASCII_SPACE;
                                        7'd55:  char_55  <= ASCII_SPACE;
                                        7'd56:  char_56  <= ASCII_SPACE;
                                        7'd57:  char_57  <= ASCII_SPACE;
                                        7'd58:  char_58  <= ASCII_SPACE;
                                        7'd59:  char_59  <= ASCII_SPACE;
                                        7'd60:  char_60  <= ASCII_SPACE;
                                        7'd61:  char_61  <= ASCII_SPACE;
                                        7'd62:  char_62  <= ASCII_SPACE;
                                        7'd63:  char_63  <= ASCII_SPACE;
                                        default: begin end
                                    endcase
                                    char_idx <= char_idx + 7'd2;
                                end
                            end
                            
                            // Advance to next number
                            if (current_num < n) begin
                                current_num <= current_num + 4'd1;
                            end else begin
                                state <= COMPLETE;
                            end
                        end else begin
                            state <= COMPLETE;
                        end
                    end else begin
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule