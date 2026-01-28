module phone_network(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] valid_detectors,
    input wire [7:0] pos_0, pos_1, pos_2, pos_3,
    input wire [7:0] pos_4, pos_5, pos_6, pos_7,
    input wire [31:0] count_0, count_1, count_2, count_3,
    input wire [31:0] count_4, count_5, count_6, count_7,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SORT = 2'd1;
    localparam [1:0] CALC = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;
    
    // Internal registers
    reg [1:0] state;
    reg [2:0] n_detectors;
    reg [2:0] sort_idx;
    reg [2:0] sort_limit;
    reg [2:0] calc_idx;
    reg [31:0] temp_result;
    
    // Packed arrays for sorting (8x8 for pos, 8x32 for count)
    reg [63:0] pos_reg;  // pos_reg[7:0] = pos_0, pos_reg[15:8] = pos_1, etc.
    reg [255:0] count_reg;  // count_reg[31:0] = count_0, count_reg[63:32] = count_1, etc.
    
    // Localparams for packed array indices
    localparam [7:0] POS0_MASK = 8'hFF;
    localparam [7:0] POS1_MASK = 8'hFF;
    localparam [7:0] POS2_MASK = 8'hFF;
    localparam [7:0] POS3_MASK = 8'hFF;
    localparam [7:0] POS4_MASK = 8'hFF;
    localparam [7:0] POS5_MASK = 8'hFF;
    localparam [7:0] POS6_MASK = 8'hFF;
    localparam [7:0] POS7_MASK = 8'hFF;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            n_detectors <= 3'd0;
            sort_idx <= 3'd0;
            sort_limit <= 3'd0;
            calc_idx <= 3'd0;
            temp_result <= 32'd0;
            pos_reg <= 64'd0;
            count_reg <= 256'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load inputs into packed arrays
                        pos_reg <= {pos_7, pos_6, pos_5, pos_4, pos_3, pos_2, pos_1, pos_0};
                        count_reg <= {count_7, count_6, count_5, count_4, count_3, count_2, count_1, count_0};
                        n_detectors <= valid_detectors;
                        sort_idx <= 3'd0;
                        if (valid_detectors > 3'd1)
                            sort_limit <= valid_detectors - 3'd1;
                        else
                            sort_limit <= 3'd0;
                        state <= SORT;
                    end
                end
                
                SORT: begin
                    if (sort_idx < sort_limit) begin
                        // Compare adjacent positions
                        if (pos_reg[(sort_idx + 3'd1)*8 +: 8] < pos_reg[sort_idx*8 +: 8]) begin
                            // Swap positions
                            pos_reg[sort_idx*8 +: 8] <= pos_reg[(sort_idx + 3'd1)*8 +: 8];
                            pos_reg[(sort_idx + 3'd1)*8 +: 8] <= pos_reg[sort_idx*8 +: 8];
                            // Swap counts
                            count_reg[sort_idx*32 +: 32] <= count_reg[(sort_idx + 3'd1)*32 +: 32];
                            count_reg[(sort_idx + 3'd1)*32 +: 32] <= count_reg[sort_idx*32 +: 32];
                        end
                        sort_idx <= sort_idx + 3'd1;
                    end else begin
                        if (sort_limit > 3'd0) begin
                            sort_limit <= sort_limit - 3'd1;
                            sort_idx <= 3'd0;
                        end else begin
                            temp_result <= count_reg[31:0];
                            calc_idx <= 3'd1;
                            state <= CALC;
                        end
                    end
                end
                
                CALC: begin
                    if (calc_idx < n_detectors) begin
                        if (count_reg[calc_idx*32 +: 32] > count_reg[(calc_idx - 3'd1)*32 +: 32]) begin
                            temp_result <= temp_result + 
                                (count_reg[calc_idx*32 +: 32] - count_reg[(calc_idx - 3'd1)*32 +: 32]);
                        end
                        calc_idx <= calc_idx + 3'd1;
                    end else begin
                        result <= temp_result;
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule