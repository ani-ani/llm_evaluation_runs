module ArrayAbsoluteDifference(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] score_0,
    input signed [7:0] score_1,
    input signed [7:0] score_2,
    input signed [7:0] score_3,
    input signed [7:0] score_4,
    input signed [7:0] score_5,
    input signed [7:0] score_6,
    input signed [7:0] score_7,
    input signed [7:0] guess_0,
    input signed [7:0] guess_1,
    input signed [7:0] guess_2,
    input signed [7:0] guess_3,
    input signed [7:0] guess_4,
    input signed [7:0] guess_5,
    input signed [7:0] guess_6,
    input signed [7:0] guess_7,
    input [3:0] length,
    output reg [7:0] diff_0,
    output reg [7:0] diff_1,
    output reg [7:0] diff_2,
    output reg [7:0] diff_3,
    output reg [7:0] diff_4,
    output reg [7:0] diff_5,
    output reg [7:0] diff_6,
    output reg [7:0] diff_7,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            diff_0 <= 8'd0;
            diff_1 <= 8'd0;
            diff_2 <= 8'd0;
            diff_3 <= 8'd0;
            diff_4 <= 8'd0;
            diff_5 <= 8'd0;
            diff_6 <= 8'd0;
            diff_7 <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    diff_0 <= (score_0 - guess_0) >= 8'd0 ? (score_0 - guess_0) : -(score_0 - guess_0);
                    diff_1 <= (score_1 - guess_1) >= 8'd0 ? (score_1 - guess_1) : -(score_1 - guess_1);
                    diff_2 <= (score_2 - guess_2) >= 8'd0 ? (score_2 - guess_2) : -(score_2 - guess_2);
                    diff_3 <= (score_3 - guess_3) >= 8'd0 ? (score_3 - guess_3) : -(score_3 - guess_3);
                    diff_4 <= (score_4 - guess_4) >= 8'd0 ? (score_4 - guess_4) : -(score_4 - guess_4);
                    diff_5 <= (score_5 - guess_5) >= 8'd0 ? (score_5 - guess_5) : -(score_5 - guess_5);
                    diff_6 <= (score_6 - guess_6) >= 8'd0 ? (score_6 - guess_6) : -(score_6 - guess_6);
                    diff_7 <= (score_7 - guess_7) >= 8'd0 ? (score_7 - guess_7) : -(score_7 - guess_7);
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule