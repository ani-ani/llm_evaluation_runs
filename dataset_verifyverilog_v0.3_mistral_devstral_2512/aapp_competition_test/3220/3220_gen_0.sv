module circle_dance(
    input clk,
    input rst_n,
    input start,
    input [7:0] p_0,
    input [7:0] p_1,
    input [7:0] p_2,
    input [7:0] p_3,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] SEARCH    = 4'd1;
    localparam [3:0] COMPLETE  = 4'd2;

    // Internal registers
    reg [3:0] state;
    reg [3:0] combination;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Compute new positions for current combination
    wire [1:0] pos_0 = (combination[0] == 1'b0) ? ((0 + p_0) % 4) : ((0 - p_0 + 4) % 4);
    wire [1:0] pos_1 = (combination[1] == 1'b0) ? ((1 + p_1) % 4) : ((1 - p_1 + 4) % 4);
    wire [1:0] pos_2 = (combination[2] == 1'b0) ? ((2 + p_2) % 4) : ((2 - p_2 + 4) % 4);
    wire [1:0] pos_3 = (combination[3] == 1'b0) ? ((3 + p_3) % 4) : ((3 - p_3 + 4) % 4);

    // Check for collisions
    wire no_collision = 
        (pos_0 != pos_1) && (pos_0 != pos_2) && (pos_0 != pos_3) &&
        (pos_1 != pos_2) && (pos_1 != pos_3) &&
        (pos_2 != pos_3);

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            combination <= 4'd0;
            cycle_count <= 8'd0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SEARCH;
                        combination <= 4'd0;
                    end
                end

                SEARCH: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current combination is valid
                    if (no_collision) begin
                        // Output ASCII values
                        result_0 <= (combination[0] == 1'b0) ? 8'd76 : 8'd82; // 'L' or 'R'
                        result_1 <= (combination[1] == 1'b0) ? 8'd76 : 8'd82;
                        result_2 <= (combination[2] == 1'b0) ? 8'd76 : 8'd82;
                        result_3 <= (combination[3] == 1'b0) ? 8'd76 : 8'd82;
                        valid <= 1'b1;
                        state <= COMPLETE;
                    end else if (combination == 4'd15 || cycle_count >= MAX_CYCLES) begin
                        // No solution found
                        valid <= 1'b0;
                        state <= COMPLETE;
                    end else begin
                        // Try next combination
                        combination <= combination + 4'd1;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule