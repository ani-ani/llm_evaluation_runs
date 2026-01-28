module absolute_difference(
    input clk,
    input rst_n,
    input start,
    input [7:0] score_0,
    input [7:0] score_1,
    input [7:0] score_2,
    input [7:0] score_3,
    input [7:0] score_4,
    input [7:0] score_5,
    input [7:0] score_6,
    input [7:0] score_7,
    input [7:0] guess_0,
    input [7:0] guess_1,
    input [7:0] guess_2,
    input [7:0] guess_3,
    input [7:0] guess_4,
    input [7:0] guess_5,
    input [7:0] guess_6,
    input [7:0] guess_7,
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

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] DONE_STATE = 3'd2;
    
    reg [2:0] state, next_state;
    reg [2:0] index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Combinatorial subtraction results for all 8 elements
    wire signed [8:0] sub_0;
    wire signed [8:0] sub_1;
    wire signed [8:0] sub_2;
    wire signed [8:0] sub_3;
    wire signed [8:0] sub_4;
    wire signed [8:0] sub_5;
    wire signed [8:0] sub_6;
    wire signed [8:0] sub_7;
    
    // Signed subtraction (9 bits to prevent overflow)
    assign sub_0 = {score_0[7], score_0} - {guess_0[7], guess_0};
    assign sub_1 = {score_1[7], score_1} - {guess_1[7], guess_1};
    assign sub_2 = {score_2[7], score_2} - {guess_2[7], guess_2};
    assign sub_3 = {score_3[7], score_3} - {guess_3[7], guess_3};
    assign sub_4 = {score_4[7], score_4} - {guess_4[7], guess_4};
    assign sub_5 = {score_5[7], score_5} - {guess_5[7], guess_5};
    assign sub_6 = {score_6[7], score_6} - {guess_6[7], guess_6};
    assign sub_7 = {score_7[7], score_7} - {guess_7[7], guess_7};
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? COMPUTE : IDLE;
            COMPUTE: next_state = (cycle_count >= MAX_CYCLES || index >= length) ? DONE_STATE : COMPUTE;
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            diff_0 <= 8'd0;
            diff_1 <= 8'd0;
            diff_2 <= 8'd0;
            diff_3 <= 8'd0;
            diff_4 <= 8'd0;
            diff_5 <= 8'd0;
            diff_6 <= 8'd0;
            diff_7 <= 8'd0;
        end else begin
            state <= next_state;
            
            case (next_state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 3'd0;
                    cycle_count <= 8'd0;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute each element based on index
                    if (index == 3'd0) begin
                        if (sub_0[8]) diff_0 <= -sub_0[7:0];
                        else diff_0 <= sub_0[7:0];
                    end
                    if (index == 3'd1) begin
                        if (sub_1[8]) diff_1 <= -sub_1[7:0];
                        else diff_1 <= sub_1[7:0];
                    end
                    if (index == 3'd2) begin
                        if (sub_2[8]) diff_2 <= -sub_2[7:0];
                        else diff_2 <= sub_2[7:0];
                    end
                    if (index == 3'd3) begin
                        if (sub_3[8]) diff_3 <= -sub_3[7:0];
                        else diff_3 <= sub_3[7:0];
                    end
                    if (index == 3'd4) begin
                        if (sub_4[8]) diff_4 <= -sub_4[7:0];
                        else diff_4 <= sub_4[7:0];
                    end
                    if (index == 3'd5) begin
                        if (sub_5[8]) diff_5 <= -sub_5[7:0];
                        else diff_5 <= sub_5[7:0];
                    end
                    if (index == 3'd6) begin
                        if (sub_6[8]) diff_6 <= -sub_6[7:0];
                        else diff_6 <= sub_6[7:0];
                    end
                    if (index == 3'd7) begin
                        if (sub_7[8]) diff_7 <= -sub_7[7:0];
                        else diff_7 <= sub_7[7:0];
                    end
                    
                    index <= index + 3'd1;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    index <= 3'd0;
                    cycle_count <= 8'd0;
                end
                
                default: begin
                    state <= IDLE;
                    index <= 3'd0;
                    cycle_count <= 8'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule