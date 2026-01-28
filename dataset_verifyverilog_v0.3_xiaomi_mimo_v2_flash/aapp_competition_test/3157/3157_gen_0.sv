module hash_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,      // Word length (1-10)
    input wire [24:0] K,     // Target hash value
    input wire [4:0] M,      // MOD = 2^M
    output reg [47:0] result,
    output reg done
);

    // MOD = 2^M, but we use parameter for maximum M=25
    wire [24:0] MOD = (1 << M);
    wire [24:0] MOD_MASK = MOD - 1;
    
    // State definitions
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] COMPUTE = 3'b001;
    localparam [2:0] UPDATE = 3'b010;
    localparam [2:0] CHECK_DONE = 3'b011;
    localparam [2:0] FINISH = 3'b100;
    
    reg [2:0] state;
    reg [3:0] len_counter;      // Current word length (0 to N)
    reg [24:0] state_counter;   // Current hash state
    reg [4:0] letter_counter;   // Current letter (1-26)
    
    // DP arrays - use distributed RAM for better synthesis
    reg [47:0] dp_current [0:255];  // Current states (only use up to 2^M)
    reg [47:0] dp_next [0:255];     // Next states
    
    // Initialize dp_current[0] = 1 for empty word
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dp_current[0] <= 48'd1;
            // Initialize other entries to 0
            for (integer i = 1; i < 256; i = i + 1) begin
                dp_current[i] <= 48'd0;
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 48'd0;
            len_counter <= 4'd0;
            state_counter <= 25'd0;
            letter_counter <= 5'd0;
            // Reset dp_next
            for (integer i = 0; i < 256; i = i + 1) begin
                dp_next[i] <= 48'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Reset dp_next for new computation
                        for (integer i = 0; i < 256; i = i + 1) begin
                            dp_next[i] <= 48'd0;
                        end
                        len_counter <= 4'd1;  // Start with length 1
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Process current state for all 26 letters
                    if (letter_counter < 26) begin
                        // Calculate new state: (current * 33) XOR (letter+1) mod MOD
                        // Note: ord('a')=1, so letter_counter+1
                        reg [24:0] new_state;
                        new_state = ((state_counter * 33) ^ (letter_counter + 1)) & MOD_MASK;
                        
                        // Accumulate count
                        dp_next[new_state] <= dp_next[new_state] + dp_current[state_counter];
                        
                        letter_counter <= letter_counter + 1;
                    end else begin
                        // Done with all letters for this state
                        letter_counter <= 5'd0;
                        state <= UPDATE;
                    end
                end
                
                UPDATE: begin
                    // Move to next state
                    if (state_counter < MOD && state_counter < 255) begin
                        state_counter <= state_counter + 1;
                        state <= COMPUTE;
                    end else begin
                        // Done with all states for this length
                        state_counter <= 25'd0;
                        state <= CHECK_DONE;
                    end
                end
                
                CHECK_DONE: begin
                    // Copy dp_next to dp_current for next iteration
                    for (integer i = 0; i < 256; i = i + 1) begin
                        if (i < MOD) begin
                            dp_current[i] <= dp_next[i];
                            dp_next[i] <= 48'd0;  // Reset for next use
                        end else begin
                            dp_current[i] <= 48'd0;
                            dp_next[i] <= 48'd0;
                        end
                    end
                    
                    if (len_counter >= N) begin
                        state <= FINISH;
                    end else begin
                        len_counter <= len_counter + 1;
                        state <= COMPUTE;
                    end
                end
                
                FINISH: begin
                    // Return result for target K (if K < MOD)
                    if (K < MOD) begin
                        result <= dp_current[K];
                    end else begin
                        result <= 48'd0;
                    end
                    done <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule