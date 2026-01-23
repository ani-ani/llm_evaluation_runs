module iscube (
    input clk,
    input rst_n,
    input start,
    input signed [7:0] a,
    output reg result,
    output reg done
);

    // States
    localparam IDLE     = 2'b00;
    localparam CHECKING = 2'b01;
    localparam DONE     = 2'b10;

    reg [1:0] current_state, next_state;
    reg [3:0] count;       // Counter to track root iteration (0 to 10)
    reg signed [4:0] root; // Current root (-5 to 5)
    reg signed [11:0] cube; // Cube of root (max 125, min -125, fits in 12 bits)
    reg found;             // Flag if cube match found

    // State Transition and Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            count <= 4'd0;
            found <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    if (start) begin
                        current_state <= CHECKING;
                        count <= 4'd0;
                        found <= 1'b0;
                    end
                end

                CHECKING: begin
                    // Calculate current root and cube
                    // Mapping count to roots:
                    // 0:0, 1:1, 2:-1, 3:2, 4:-2, 5:3, 6:-3, 7:4, 8:-4, 9:5, 10:-5
                    case (count)
                        4'd0: root <= 5'sd0;
                        4'd1: root <= 5'sd1;
                        4'd2: root <= -5'sd1;
                        4'd3: root <= 5'sd2;
                        4'd4: root <= -5'sd2;
                        4'd5: root <= 5'sd3;
                        4'd6: root <= -5'sd3;
                        4'd7: root <= 5'sd4;
                        4'd8: root <= -5'sd4;
                        4'd9: root <= 5'sd5;
                        4'd10: root <= -5'sd5;
                        default: root <= 5'sd0;
                    endcase

                    // Compute cube (latency of multiplication adds to cycle count)
                    cube <= root * root * root;

                    // Check match
                    // Since cube updates every clock, we check the value generated in previous cycle
                    // Or we can check directly if we assume combinational check, 
                    // but standard sequential design implies registering the check.
                    // We check the 'cube' value computed from the registered 'root' of the previous cycle.
                    // To avoid off-by-one, we update 'found' based on current 'cube' vs 'a'.
                    // However, 'cube' is registered, so by the time we are in CHECKING state cycle N,
                    // 'cube' contains the result of root for cycle N-1.
                    // Let's refine logic to be robust:
                    // We will check the 'cube' computed from the 'root' set in the *previous* cycle.
                    // But actually, let's just use a combinational check on the current cycle's inputs 
                    // to make it faster, or keep it registered. The problem asks for ~20 cycles.
                    
                    // Let's stick to the registered approach:
                    // In cycle i, we set root. In cycle i+1, cube is ready.
                    // To fill the pipeline, we need to handle latency.
                    // Alternatively, since max 11 iterations, if we use combinational logic for the comparison
                    // inside the state machine, we can do it in 11 cycles. 
                    // Given the prompt asks for 20 cycles, a pipelined approach or just waiting is fine.
                    // Let's use the registered cube from the previous iteration.
                    
                    // We increment count every cycle.
                    // If cube == a (from previous root calculation), set found.
                    // Note: First cycle, cube is garbage (0). We must skip check or handle.
                    // Let's use a valid flag for cube.
                    
                    if (count > 0) begin
                        if (cube == a) begin
                            found <= 1'b1;
                        end
                    end

                    if (count == 4'd10) begin
                        current_state <= DONE;
                        if (cube == a || found) // Check last calculated cube too
                            result <= 1'b1;
                        else
                            result <= 1'b0;
                        done <= 1'b1;
                    end else begin
                        count <= count + 1'b1;
                    end
                end

                DONE: begin
                    // Wait for start to go low or next reset
                    if (!start) begin
                        current_state <= IDLE;
                        done <= 1'b0;
                        result <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule
