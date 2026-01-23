module dict_sorter(
    input clk,
    input rst_n,
    input start,
    input [7:0] key_0, key_1, key_2, key_3, key_4, key_5, key_6, key_7,
    input [15:0] value_0, value_1, value_2, value_3, value_4, value_5, value_6, value_7,
    output reg [7:0] out_key_0, out_key_1, out_key_2, out_key_3,
    output reg [15:0] out_value_0, out_value_1, out_value_2, out_value_3,
    output reg done
);

    // State encoding
    localparam IDLE = 5'd0;
    localparam SORT_1 = 5'd1;
    localparam SORT_2 = 5'd2;
    localparam SORT_3 = 5'd3;
    localparam SORT_4 = 5'd4;
    localparam SORT_5 = 5'd5;
    localparam SORT_6 = 5'd6;
    localparam SORT_7 = 5'd7;
    localparam SORT_8 = 5'd8;
    localparam SORT_9 = 5'd9;
    localparam SORT_10 = 5'd10;
    localparam SORT_11 = 5'd11;
    localparam SORT_12 = 5'd12;
    localparam SORT_13 = 5'd13;
    localparam SORT_14 = 5'd14;
    localparam SORT_15 = 5'd15;
    localparam SORT_16 = 5'd16;
    localparam SORT_17 = 5'd17;
    localparam SORT_18 = 5'd18;
    localparam SORT_19 = 5'd19;
    localparam SORT_20 = 5'd20;
    localparam SORT_21 = 5'd21;
    localparam SORT_22 = 5'd22;
    localparam SORT_23 = 5'd23;
    localparam SORT_24 = 5'd24;
    localparam SORT_25 = 5'd25;
    localparam SORT_26 = 5'd26;
    localparam SORT_27 = 5'd27;
    localparam SORT_28 = 5'd28;
    localparam DONE = 5'd29;

    reg [4:0] state;
    
    // Register file for sorting: 8 entries of (key, value)
    reg [7:0]  keys [0:7];
    reg [15:0] vals [0:7];
    
    // Temporary variables for comparison logic
    reg [7:0]  tmp_key;
    reg [15:0] tmp_val;
    reg        swap;

    integer i;

    // State transition and sorting logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            // Clear outputs
            out_key_0 <= 8'h0; out_value_0 <= 16'h0;
            out_key_1 <= 8'h0; out_value_1 <= 16'h0;
            out_key_2 <= 8'h0; out_value_2 <= 16'h0;
            out_key_3 <= 8'h0; out_value_3 <= 16'h0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load inputs into registers
                        keys[0] <= key_0; vals[0] <= value_0;
                        keys[1] <= key_1; vals[1] <= value_1;
                        keys[2] <= key_2; vals[2] <= value_2;
                        keys[3] <= key_3; vals[3] <= value_3;
                        keys[4] <= key_4; vals[4] <= value_4;
                        keys[5] <= key_5; vals[5] <= value_5;
                        keys[6] <= key_6; vals[6] <= value_6;
                        keys[7] <= key_7; vals[7] <= value_7;
                        state <= SORT_1;
                    end
                end
                
                // Pass 1 (Comparisons 1-4)
                SORT_1: begin // (0,1)
                    if (vals[0] < vals[1]) begin
                        tmp_key <= keys[0]; tmp_val <= vals[0];
                        keys[0] <= keys[1]; vals[0] <= vals[1];
                        keys[1] <= tmp_key; vals[1] <= tmp_val;
                    end
                    state <= SORT_2;
                end
                SORT_2: begin // (1,2)
                    if (vals[1] < vals[2]) begin
                        tmp_key <= keys[1]; tmp_val <= vals[1];
                        keys[1] <= keys[2]; vals[1] <= vals[2];
                        keys[2] <= tmp_key; vals[2] <= tmp_val;
                    end
                    state <= SORT_3;
                end
                SORT_3: begin // (2,3)
                    if (vals[2] < vals[3]) begin
                        tmp_key <= keys[2]; tmp_val <= vals[2];
                        keys[2] <= keys[3]; vals[2] <= vals[3];
                        keys[3] <= tmp_key; vals[3] <= tmp_val;
                    end
                    state <= SORT_4;
                end
                SORT_4: begin // (3,4)
                    if (vals[3] < vals[4]) begin
                        tmp_key <= keys[3]; tmp_val <= vals[3];
                        keys[3] <= keys[4]; vals[3] <= vals[4];
                        keys[4] <= tmp_key; vals[4] <= tmp_val;
                    end
                    state <= SORT_5;
                end
                
                // Pass 2 (Comparisons 5-8)
                SORT_5: begin // (4,5)
                    if (vals[4] < vals[5]) begin
                        tmp_key <= keys[4]; tmp_val <= vals[4];
                        keys[4] <= keys[5]; vals[4] <= vals[5];
                        keys[5] <= tmp_key; vals[5] <= tmp_val;
                    end
                    state <= SORT_6;
                end
                SORT_6: begin // (5,6)
                    if (vals[5] < vals[6]) begin
                        tmp_key <= keys[5]; tmp_val <= vals[5];
                        keys[5] <= keys[6]; vals[5] <= vals[6];
                        keys[6] <= tmp_key; vals[6] <= tmp_val;
                    end
                    state <= SORT_7;
                end
                SORT_7: begin // (6,7)
                    if (vals[6] < vals[7]) begin
                        tmp_key <= keys[6]; tmp_val <= vals[6];
                        keys[6] <= keys[7]; vals[6] <= vals[7];
                        keys[7] <= tmp_key; vals[7] <= tmp_val;
                    end
                    state <= SORT_8;
                end
                SORT_8: begin // (0,1)
                    if (vals[0] < vals[1]) begin
                        tmp_key <= keys[0]; tmp_val <= vals[0];
                        keys[0] <= keys[1]; vals[0] <= vals[1];
                        keys[1] <= tmp_key; vals[1] <= tmp_val;
                    end
                    state <= SORT_9;
                end
                
                // Pass 3 (Comparisons 9-12)
                SORT_9: begin // (1,2)
                    if (vals[1] < vals[2]) begin
                        tmp_key <= keys[1]; tmp_val <= vals[1];
                        keys[1] <= keys[2]; vals[1] <= vals[2];
                        keys[2] <= tmp_key; vals[2] <= tmp_val;
                    end
                    state <= SORT_10;
                end
                SORT_10: begin // (2,3)
                    if (vals[2] < vals[3]) begin
                        tmp_key <= keys[2]; tmp_val <= vals[2];
                        keys[2] <= keys[3]; vals[2] <= vals[3];
                        keys[3] <= tmp_key; vals[3] <= tmp_val;
                    end
                    state <= SORT_11;
                end
                SORT_11: begin // (3,4)
                    if (vals[3] < vals[4]) begin
                        tmp_key <= keys[3]; tmp_val <= vals[3];
                        keys[3] <= keys[4]; vals[3] <= vals[4];
                        keys[4] <= tmp_key; vals[4] <= tmp_val;
                    end
                    state <= SORT_12;
                end
                SORT_12: begin // (4,5)
                    if (vals[4] < vals[5]) begin
                        tmp_key <= keys[4]; tmp_val <= vals[4];
                        keys[4] <= keys[5]; vals[4] <= vals[5];
                        keys[5] <= tmp_key; vals[5] <= tmp_val;
                    end
                    state <= SORT_13;
                end
                
                // Pass 4 (Comparisons 13-16)
                SORT_13: begin // (5,6)
                    if (vals[5] < vals[6]) begin
                        tmp_key <= keys[5]; tmp_val <= vals[5];
                        keys[5] <= keys[6]; vals[5] <= vals[6];
                        keys[6] <= tmp_key; vals[6] <= tmp_val;
                    end
                    state <= SORT_14;
                end
                SORT_14: begin // (6,7)
                    if (vals[6] < vals[7]) begin
                        tmp_key <= keys[6]; tmp_val <= vals[6];
                        keys[6] <= keys[7]; vals[6] <= vals[7];
                        keys[7] <= tmp_key; vals[7] <= tmp_val;
                    end
                    state <= SORT_15;
                end
                SORT_15: begin // (0,1)
                    if (vals[0] < vals[1]) begin
                        tmp_key <= keys[0]; tmp_val <= vals[0];
                        keys[0] <= keys[1]; vals[0] <= vals[1];
                        keys[1] <= tmp_key; vals[1] <= tmp_val;
                    end
                    state <= SORT_16;
                end
                SORT_16: begin // (1,2)
                    if (vals[1] < vals[2]) begin
                        tmp_key <= keys[1]; tmp_val <= vals[1];
                        keys[1] <= keys[2]; vals[1] <= vals[2];
                        keys[2] <= tmp_key; vals[2] <= tmp_val;
                    end
                    state <= SORT_17;
                end
                
                // Pass 5 (Comparisons 17-20)
                SORT_17: begin // (2,3)
                    if (vals[2] < vals[3]) begin
                        tmp_key <= keys[2]; tmp_val <= vals[2];
                        keys[2] <= keys[3]; vals[2] <= vals[3];
                        keys[3] <= tmp_key; vals[3] <= tmp_val;
                    end
                    state <= SORT_18;
                end
                SORT_18: begin // (3,4)
                    if (vals[3] < vals[4]) begin
                        tmp_key <= keys[3]; tmp_val <= vals[3];
                        keys[3] <= keys[4]; vals[3] <= vals[4];
                        keys[4] <= tmp_key; vals[4] <= tmp_val;
                    end
                    state <= SORT_19;
                end
                SORT_19: begin // (4,5)
                    if (vals[4] < vals[5]) begin
                        tmp_key <= keys[4]; tmp_val <= vals[4];
                        keys[4] <= keys[5]; vals[4] <= vals[5];
                        keys[5] <= tmp_key; vals[5] <= tmp_val;
                    end
                    state <= SORT_20;
                end
                SORT_20: begin // (5,6)
                    if (vals[5] < vals[6]) begin
                        tmp_key <= keys[5]; tmp_val <= vals[5];
                        keys[5] <= keys[6]; vals[5] <= vals[6];
                        keys[6] <= tmp_key; vals[6] <= tmp_val;
                    end
                    state <= SORT_21;
                end
                
                // Pass 6 (Comparisons 21-24)
                SORT_21: begin // (6,7)
                    if (vals[6] < vals[7]) begin
                        tmp_key <= keys[6]; tmp_val <= vals[6];
                        keys[6] <= keys[7]; vals[6] <= vals[7];
                        keys[7] <= tmp_key; vals[7] <= tmp_val;
                    end
                    state <= SORT_22;
                end
                SORT_22: begin // (0,1)
                    if (vals[0] < vals[1]) begin
                        tmp_key <= keys[0]; tmp_val <= vals[0];
                        keys[0] <= keys[1]; vals[0] <= vals[1];
                        keys[1] <= tmp_key; vals[1] <= tmp_val;
                    end
                    state <= SORT_23;
                end
                SORT_23: begin // (1,2)
                    if (vals[1] < vals[2]) begin
                        tmp_key <= keys[1]; tmp_val <= vals[1];
                        keys[1] <= keys[2]; vals[1] <= vals[2];
                        keys[2] <= tmp_key; vals[2] <= tmp_val;
                    end
                    state <= SORT_24;
                end
                SORT_24: begin // (2,3)
                    if (vals[2] < vals[3]) begin
                        tmp_key <= keys[2]; tmp_val <= vals[2];
                        keys[2] <= keys[3]; vals[2] <= vals[3];
                        keys[3] <= tmp_key; vals[3] <= tmp_val;
                    end
                    state <= SORT_25;
                end
                
                // Pass 7 (Comparisons 25-28)
                SORT_25: begin // (3,4)
                    if (vals[3] < vals[4]) begin
                        tmp_key <= keys[3]; tmp_val <= vals[3];
                        keys[3] <= keys[4]; vals[3] <= vals[4];
                        keys[4] <= tmp_key; vals[4] <= tmp_val;
                    end
                    state <= SORT_26;
                end
                SORT_26: begin // (4,5)
                    if (vals[4] < vals[5]) begin
                        tmp_key <= keys[4]; tmp_val <= vals[4];
                        keys[4] <= keys[5]; vals[4] <= vals[5];
                        keys[5] <= tmp_key; vals[5] <= tmp_val;
                    end
                    state <= SORT_27;
                end
                SORT_27: begin // (5,6)
                    if (vals[5] < vals[6]) begin
                        tmp_key <= keys[5]; tmp_val <= vals[5];
                        keys[5] <= keys[6]; vals[5] <= vals[6];
                        keys[6] <= tmp_key; vals[6] <= tmp_val;
                    end
                    state <= SORT_28;
                end
                SORT_28: begin // (6,7)
                    if (vals[6] < vals[7]) begin
                        tmp_key <= keys[6]; tmp_val <= vals[6];
                        keys[6] <= keys[7]; vals[6] <= vals[7];
                        keys[7] <= tmp_key; vals[7] <= tmp_val;
                    end
                    state <= DONE;
                    
                    // Transfer top 4 to outputs (index 0 is highest due to descending sort)
                    out_key_0 <= keys[0]; out_value_0 <= vals[0];
                    out_key_1 <= keys[1]; out_value_1 <= vals[1];
                    out_key_2 <= keys[2]; out_value_2 <= vals[2];
                    out_key_3 <= keys[3]; out_value_3 <= vals[3];
                    done <= 1'b1;
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (start) begin
                        // Re-load and restart if requested
                        keys[0] <= key_0; vals[0] <= value_0;
                        keys[1] <= key_1; vals[1] <= value_1;
                        keys[2] <= key_2; vals[2] <= value_2;
                        keys[3] <= key_3; vals[3] <= value_3;
                        keys[4] <= key_4; vals[4] <= value_4;
                        keys[5] <= key_5; vals[5] <= value_5;
                        keys[6] <= key_6; vals[6] <= value_6;
                        keys[7] <= key_7; vals[7] <= value_7;
                        done <= 1'b0;
                        state <= SORT_1;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule