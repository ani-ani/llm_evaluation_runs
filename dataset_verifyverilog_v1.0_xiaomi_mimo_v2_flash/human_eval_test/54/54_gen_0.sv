module same_chars(
    input clk,
    input rst_n,
    input start,
    input [7:0] s0 [0:7],
    input [7:0] s1 [0:7],
    output reg result,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SETUP    = 3'd1;
    localparam [2:0] PROCESS_0 = 3'd2;
    localparam [2:0] PROCESS_1 = 3'd3;
    localparam [2:0] COMPARE  = 3'd4;
    localparam [2:0] DONE     = 3'd5;
    
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] char_index;
    reg [255:0] mask0;
    reg [255:0] mask1;
    reg [7:0] temp_char;
    reg [7:0] i;
    reg [7:0] j;
    reg [7:0] k;
    reg mask_match;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd50;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = SETUP;
                else
                    next_state = IDLE;
            end
            SETUP: begin
                next_state = PROCESS_0;
            end
            PROCESS_0: begin
                if (char_index >= 8'd8)
                    next_state = PROCESS_1;
                else
                    next_state = PROCESS_0;
            end
            PROCESS_1: begin
                if (char_index >= 8'd8)
                    next_state = COMPARE;
                else
                    next_state = PROCESS_1;
            end
            COMPARE: begin
                if (k >= 8'd8)
                    next_state = DONE;
                else
                    next_state = COMPARE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            char_index <= 8'd0;
            mask0 <= 256'd0;
            mask1 <= 256'd0;
            temp_char <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            mask_match <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        char_index <= 8'd0;
                        mask0 <= 256'd0;
                        mask1 <= 256'd0;
                    end
                end
                
                SETUP: begin
                    // Initialize counters
                    char_index <= 8'd0;
                    mask_match <= 1'b0;
                end
                
                PROCESS_0: begin
                    // Build mask for s0
                    temp_char <= s0[char_index];
                    // Set bit in mask0 based on character value
                    // Using a loop to set the bit (since we can't use array slices)
                    if (char_index < 8'd8) begin
                        // Set the corresponding bit in mask0
                        mask0 <= mask0 | (256'd1 << s0[char_index]);
                        char_index <= char_index + 8'd1;
                    end
                end
                
                PROCESS_1: begin
                    // Build mask for s1
                    temp_char <= s1[char_index];
                    // Set bit in mask1
                    if (char_index < 8'd8) begin
                        mask1 <= mask1 | (256'd1 << s1[char_index]);
                        char_index <= char_index + 8'd1;
                    end
                end
                
                COMPARE: begin
                    // Compare masks - check if they are identical
                    // This needs to check bit by bit due to Icarus limitations
                    if (k < 8'd8) begin
                        // Check each 32-bit segment
                        // We'll compare segment by segment
                        if (k == 8'd0) begin
                            // Compare bits 0-31
                            if (mask0[31:0] == mask1[31:0]) begin
                                mask_match <= 1'b1;
                            end else begin
                                mask_match <= 1'b0;
                            end
                        end else if (k == 8'd1) begin
                            if (mask_match && (mask0[63:32] == mask1[63:32])) begin
                                mask_match <= 1'b1;
                            end else begin
                                mask_match <= 1'b0;
                            end
                        end else if (k == 8'd2) begin
                            if (mask_match && (mask0[95:64] == mask1[95:64])) begin
                                mask_match <= 1'b1;
                            end else begin
                                mask_match <= 1'b0;
                            end
                        end else if (k == 8'd3) begin
                            if (mask_match && (mask0[127:96] == mask1[127:96])) begin
                                mask_match <= 1'b1;
                            end else begin
                                mask_match <= 1'b0;
                            end
                        end else if (k == 8'd4) begin
                            if (mask_match && (mask0[159:128] == mask1[159:128])) begin
                                mask_match <= 1'b1;
                            end else begin
                                mask_match <= 1'b0;
                            end
                        end else if (k == 8'd5) begin
                            if (mask_match && (mask0[191:160] == mask1[191:160])) begin
                                mask_match <= 1'b1;
                            end else begin
                                mask_match <= 1'b0;
                            end
                        end else if (k == 8'd6) begin
                            if (mask_match && (mask0[223:192] == mask1[223:192])) begin
                                mask_match <= 1'b1;
                            end else begin
                                mask_match <= 1'b0;
                            end
                        end else if (k == 8'd7) begin
                            if (mask_match && (mask0[255:224] == mask1[255:224])) begin
                                mask_match <= 1'b1;
                            end else begin
                                mask_match <= 1'b0;
                            end
                        end
                        k <= k + 8'd1;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    result <= mask_match;
                    // Reset counters for next operation
                    k <= 8'd0;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule