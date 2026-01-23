module robot_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] instruction,  // 1-bit per char: 1=F, 0=T
    input wire [3:0] target_x,     // 4-bit signed (-8 to 7)
    input wire [3:0] target_y,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PARSE = 2'd1;
    localparam [1:0] CHECK = 2'd2;
    localparam [1:0] DONE = 2'd3;
    
    reg [1:0] state;
    reg [2:0] seg_idx;             // Segment index for parsing
    reg [3:0] segments [0:4];      // 5 segments
    reg [2:0] count;               // Counter for consecutive F's
    reg [2:0] i;                   // Loop variable
    reg signed [4:0] x_cand [0:8]; // X candidates
    reg signed [4:0] y_cand [0:8]; // Y candidates
    reg signed [4:0] x_target_s;
    reg signed [4:0] y_target_s;
    reg signed [4:0] x_target_adj;
    reg signed [4:0] x0_s;
    reg signed [4:0] x2_s;
    reg signed [4:0] x4_s;
    reg signed [4:0] y1_s;
    reg signed [4:0] y3_s;
    reg x_found;
    reg y_found;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            seg_idx <= 0;
            count <= 0;
            for (i = 0; i < 5; i = i + 1) begin
                segments[i] <= 0;
            end
            for (i = 0; i < 9; i = i + 1) begin
                x_cand[i] <= 0;
                y_cand[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= PARSE;
                        seg_idx <= 0;
                        count <= 0;
                    end
                end
                
                PARSE: begin
                    // Parse instruction bit by bit
                    if (seg_idx < 8) begin
                        if (instruction[seg_idx]) begin
                            count <= count + 1;
                        end else begin
                            if (seg_idx < 5) begin
                                segments[seg_idx] <= count;
                            end
                            count <= 0;
                        end
                        seg_idx <= seg_idx + 1;
                    end else begin
                        // Last segment
                        if (seg_idx == 8) begin
                            if (count > 0) begin
                                if (4'd4 >= seg_idx) begin
                                    segments[seg_idx] <= count;
                                end
                            end
                            seg_idx <= seg_idx + 1;
                        end else begin
                            state <= CHECK;
                        end
                    end
                end
                
                CHECK: begin
                    // Compute signed values
                    x0_s <= $signed({1'b0, segments[0]});
                    x2_s <= $signed({1'b0, segments[2]});
                    x4_s <= $signed({1'b0, segments[4]});
                    y1_s <= $signed({1'b0, segments[1]});
                    y3_s <= $signed({1'b0, segments[3]});
                    x_target_s <= $signed(target_x);
                    y_target_s <= $signed(target_y);
                    
                    // Generate candidates
                    x_cand[0] <= 0;
                    x_cand[1] <= $signed({1'b0, segments[2]});
                    x_cand[2] <= -$signed({1'b0, segments[2]});
                    x_cand[3] <= $signed({1'b0, segments[4]});
                    x_cand[4] <= -$signed({1'b0, segments[4]});
                    x_cand[5] <= $signed({1'b0, segments[2]}) + $signed({1'b0, segments[4]});
                    x_cand[6] <= $signed({1'b0, segments[2]}) - $signed({1'b0, segments[4]});
                    x_cand[7] <= -$signed({1'b0, segments[2]}) + $signed({1'b0, segments[4]});
                    x_cand[8] <= -$signed({1'b0, segments[2]}) - $signed({1'b0, segments[4]});
                    
                    y_cand[0] <= 0;
                    y_cand[1] <= $signed({1'b0, segments[1]});
                    y_cand[2] <= -$signed({1'b0, segments[1]});
                    y_cand[3] <= $signed({1'b0, segments[3]});
                    y_cand[4] <= -$signed({1'b0, segments[3]});
                    y_cand[5] <= $signed({1'b0, segments[1]}) + $signed({1'b0, segments[3]});
                    y_cand[6] <= $signed({1'b0, segments[1]}) - $signed({1'b0, segments[3]});
                    y_cand[7] <= -$signed({1'b0, segments[1]}) + $signed({1'b0, segments[3]});
                    y_cand[8] <= -$signed({1'b0, segments[1]}) - $signed({1'b0, segments[3]});
                    
                    state <= DONE;
                    x_found <= 0;
                    y_found <= 0;
                end
                
                DONE: begin
                    // Check if target matches any candidate
                    x_target_adj <= x_target_s - $signed({1'b0, segments[0]});
                    
                    // Check X
                    if (x_target_adj == x_cand[0] || x_target_adj == x_cand[1] ||
                        x_target_adj == x_cand[2] || x_target_adj == x_cand[3] ||
                        x_target_adj == x_cand[4] || x_target_adj == x_cand[5] ||
                        x_target_adj == x_cand[6] || x_target_adj == x_cand[7] ||
                        x_target_adj == x_cand[8]) begin
                        x_found <= 1;
                    end
                    
                    // Check Y
                    if (y_target_s == y_cand[0] || y_target_s == y_cand[1] ||
                        y_target_s == y_cand[2] || y_target_s == y_cand[3] ||
                        y_target_s == y_cand[4] || y_target_s == y_cand[5] ||
                        y_target_s == y_cand[6] || y_target_s == y_cand[7] ||
                        y_target_s == y_cand[8]) begin
                        y_found <= 1;
                    end
                    
                    result <= x_found && y_found;
                    done <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule

module top (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] instruction,
    input wire [3:0] target_x,
    input wire [3:0] target_y,
    output wire result,
    output wire done
);
    robot_checker rc (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .instruction(instruction),
        .target_x(target_x),
        .target_y(target_y),
        .result(result),
        .done(done)
    );
endmodule