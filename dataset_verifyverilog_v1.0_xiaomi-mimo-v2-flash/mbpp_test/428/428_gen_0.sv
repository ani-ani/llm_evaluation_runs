module ShellSort (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] data_in,
    output reg [127:0] data_out,
    output reg done,
    output reg busy
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] INIT_GAP    = 4'd1;
    localparam [3:0] OUTER_LOOP  = 4'd2;
    localparam [3:0] INNER_LOOP  = 4'd3;
    localparam [3:0] COMPARE     = 4'd4;
    localparam [3:0] SWAP        = 4'd5;
    localparam [3:0] UPDATE_J    = 4'd6;
    localparam [3:0] NEXT_GAP    = 4'd7;
    localparam [3:0] FINISH      = 4'd8;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] data_reg [0:15];  // Internal storage array
    reg [3:0] gap;              // Gap value (8,4,2,1,0)
    reg [3:0] i;                // Outer loop index
    reg [3:0] j;                // Inner loop index
    reg [3:0] temp_j;           // Temp j for swap
    reg [7:0] temp_val;         // Value being compared
    reg [7:0] cycle_count;      // Safety counter
    localparam [7:0] MAX_CYCLES = 8'd200;  // Safe limit
    
    // Helper variables
    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize ALL registers
            state <= IDLE;
            gap <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            temp_j <= 4'd0;
            temp_val <= 8'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            busy <= 1'b0;
            data_out <= 128'd0;
            // Initialize data_reg
            for (idx = 0; idx < 16; idx = idx + 1) begin
                data_reg[idx] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    cycle_count <= 8'd0;
                    gap <= 4'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    temp_j <= 4'd0;
                    temp_val <= 8'd0;
                    // Load input data into registers
                    for (idx = 0; idx < 16; idx = idx + 1) begin
                        data_reg[idx] <= data_in[(idx*8)+:8];
                    end
                end
                
                INIT_GAP: begin
                    busy <= 1'b1;
                    gap <= 4'd8;  // Start with gap = 8
                    i <= 4'd8;    // Start outer loop from gap
                end
                
                OUTER_LOOP: begin
                    // i starts from gap (already set in INIT_GAP)
                    j <= i;
                    temp_j <= i;
                    temp_val <= data_reg[i];
                end
                
                INNER_LOOP: begin
                    // j has been decremented in UPDATE_J
                    // temp_j holds the current j for this iteration
                    if (temp_j >= gap && data_reg[temp_j - gap] > temp_val) begin
                        // Continue inner loop: shift element up
                        data_reg[temp_j] <= data_reg[temp_j - gap];
                        temp_j <= temp_j - gap;
                    end else begin
                        // Inner loop complete, place element
                        data_reg[temp_j] <= temp_val;
                    end
                end
                
                COMPARE: begin
                    // Compare for inner loop condition
                    // Handled in combinational logic below
                end
                
                SWAP: begin
                    // Element placement already handled in INNER_LOOP
                end
                
                UPDATE_J: begin
                    // i increment handled in combinational logic
                end
                
                NEXT_GAP: begin
                    // Next gap calculation
                    if (gap > 4'd1) begin
                        gap <= gap >> 1;  // Divide by 2
                        i <= (gap >> 1);  // Set new i for outer loop
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    // Output sorted data
                    for (idx = 0; idx < 16; idx = idx + 1) begin
                        data_out[(idx*8)+:8] <= data_reg[idx];
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Safety: increment cycle counter if busy
            if (busy) begin
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT_GAP;
            end
            
            INIT_GAP: begin
                if (gap > 4'd0) next_state = OUTER_LOOP;
                else next_state = FINISH;
            end
            
            OUTER_LOOP: begin
                next_state = INNER_LOOP;
            end
            
            INNER_LOOP: begin
                // Check inner loop condition: j >= gap && data[j-gap] > temp_val
                // But we need to wait for j to be updated
                // Since j is only updated in UPDATE_J, check condition here
                if (temp_j >= gap && data_reg[temp_j - gap] > temp_val) begin
                    next_state = UPDATE_J;  // Continue inner loop
                end else begin
                    next_state = UPDATE_J;  // Inner loop done, place element
                end
            end
            
            UPDATE_J: begin
                // Update j for next inner iteration
                // If j >= gap, continue outer loop
                if (j > gap && (j - gap) >= gap) begin
                    j <= j - gap;
                    temp_j <= j - gap;
                    temp_val <= temp_val;  // Keep same temp_val
                    next_state = INNER_LOOP;
                end else begin
                    // Move to next i in outer loop
                    if (i < 4'd15) begin
                        i <= i + 4'd1;
                        next_state = OUTER_LOOP;
                    end else begin
                        // Outer loop done for this gap
                        next_state = NEXT_GAP;
                    end
                end
            end
            
            NEXT_GAP: begin
                if (gap > 4'd1) begin
                    next_state = OUTER_LOOP;
                end else begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Safety timeout
        if (busy && cycle_count >= MAX_CYCLES) begin
            next_state = FINISH;
        end
    end

endmodule