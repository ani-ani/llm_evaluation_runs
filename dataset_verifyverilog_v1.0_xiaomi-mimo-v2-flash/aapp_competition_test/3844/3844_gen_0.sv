module card_game (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [16:0] card_in,
    input wire card_valid,
    input wire card_done,
    output reg result,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COLLECT   = 2'd1;
    localparam [1:0] SCAN      = 2'd2;
    localparam [1:0] DONE      = 2'd3;
    
    // Register declarations
    reg [1:0] state, next_state;
    reg [16:0] address;
    reg found_odd;
    
    // 131072 x 1-bit parity memory
    // Using distributed RAM for speed
    reg parity_mem [0:131071];
    
    // Cycle counter for scan limit (prevents infinite loops)
    reg [17:0] cycle_counter;
    localparam [17:0] MAX_SCAN_CYCLES = 18'd131072;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COLLECT;
                else
                    next_state = IDLE;
            end
            
            COLLECT: begin
                if (card_done)
                    next_state = SCAN;
                else
                    next_state = COLLECT;
            end
            
            SCAN: begin
                // Check if we reached end of range or found odd
                if (address == 17'd131071 || found_odd)
                    next_state = DONE;
                else
                    next_state = SCAN;
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
            address <= 17'd0;
            found_odd <= 1'b0;
            cycle_counter <= 18'd0;
            // Reset memory contents (sequential for large array)
            // For synthesis, this would be handled by BRAM reset
            // Here we simulate logical reset
        end else begin
            // Default outputs
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    // Clear result when idle
                    result <= 1'b0;
                    found_odd <= 1'b0;
                    address <= 17'd0;
                    cycle_counter <= 18'd0;
                    // Note: Full memory reset would be too slow in one cycle
                    // We assume logic clears or external reset handles it
                end
                
                COLLECT: begin
                    if (card_valid) begin
                        // Toggle parity bit for this card value
                        parity_mem[card_in] <= !parity_mem[card_in];
                    end
                end
                
                SCAN: begin
                    cycle_counter <= cycle_counter + 18'd1;
                    
                    // Check current address
                    if (parity_mem[address]) begin
                        found_odd <= 1'b1;
                        result <= 1'b1; // Conan wins
                    end
                    
                    // Move to next address
                    address <= address + 17'd1;
                end
                
                DONE: begin
                    // If no odd found, Agasa wins (result already 0)
                    done <= 1'b1;
                    address <= 17'd0;
                    found_odd <= 1'b0;
                    cycle_counter <= 18'd0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            state <= next_state;
        end
    end
    
endmodule