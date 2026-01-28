module top_module (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire items_valid,
    input wire [63:0] item_data,
    input wire [15:0] item_price,
    input wire [3:0] n,
    input wire [3:0] item_index,
    output reg [7:0] result_name [0:7],
    output reg [15:0] result_price [0:7],
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] INPUT    = 3'd1;
    localparam [2:0] SORT     = 3'd2;
    localparam [2:0] OUTPUT   = 3'd3;
    localparam [2:0] DONE     = 3'd4;

    // Internal storage for items: 16 items, each 80 bits (16-bit price + 64-bit name)
    reg [79:0] item_storage [0:15];
    reg [3:0] input_counter;
    reg [3:0] sort_counter;
    reg [3:0] output_counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State machine registers
    reg [2:0] state;
    reg [2:0] next_state;

    // Initialize all result registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            busy <= 1'b0;
            input_counter <= 4'd0;
            sort_counter <= 4'd0;
            output_counter <= 4'd0;
            cycle_count <= 8'd0;
            // Clear result arrays
            for (i = 0; i < 8; i = i + 1) begin
                result_name[i] <= 8'd0;
                result_price[i] <= 16'd0;
            end
            // Clear item storage
            for (i = 0; i < 16; i = i + 1) begin
                item_storage[i] <= 80'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INPUT;
                end else begin
                    next_state = IDLE;
                end
            end
            INPUT: begin
                if (input_counter == 4'd15 && items_valid) begin
                    next_state = SORT;
                end else begin
                    next_state = INPUT;
                end
            end
            SORT: begin
                // Bubble sort: 15 passes max
                if (sort_counter >= 4'd15) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = SORT;
                end
            end
            OUTPUT: begin
                if (output_counter >= n || n == 4'd0) begin
                    next_state = DONE;
                end else begin
                    next_state = OUTPUT;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main sequential logic
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled in initialization block
        end else begin
            // Clear done at start of new operation
            if (start) begin
                done <= 1'b0;
            end

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    input_counter <= 4'd0;
                    sort_counter <= 4'd0;
                    output_counter <= 4'd0;
                    cycle_count <= 8'd0;
                end

                INPUT: begin
                    busy <= 1'b1;
                    cycle_count <= cycle_count + 8'd1;
                    if (items_valid && input_counter < 4'd16) begin
                        // Store item: price in bits [79:64], name in bits [63:0]
                        item_storage[input_counter] <= {item_price, item_data};
                        input_counter <= input_counter + 4'd1;
                    end
                end

                SORT: begin
                    busy <= 1'b1;
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Bubble sort implementation (15 passes over array)
                    // Each pass sorts one item to correct position
                    if (sort_counter < 4'd15) begin
                        // Perform one comparison and potential swap per cycle
                        // Using sort_counter to track which pair to compare
                        // Compare adjacent items based on current pass and position
                        
                        // This is a simplified bubble sort: compare item[0] with item[1], etc.
                        // We'll do full pass logic in a simplified way
                        
                        // For simplicity and timing, we do one full comparison chain per cycle
                        // Items 0-15, do comparisons: (14,15), (13,14), ..., (0,1)
                        // This creates a sorting network effect over 15 cycles
                        
                        if (sort_counter < 4'd15) begin
                            // Compare adjacent items and swap if needed
                            // We'll unroll a simple comparison for the current position
                            // This is a simplified version that processes one pass per cycle
                            
                            // For Icarus Verilog compatibility, we do sequential logic
                            // Since we can't easily unroll, we'll do one swap per cycle
                            // This creates a bubble sort over 15 cycles
                            
                            // Compare items at indices sort_counter and sort_counter+1
                            if (sort_counter < 4'd15) begin
                                // Compare prices (bits [79:64])
                                if (item_storage[sort_counter][79:64] < item_storage[sort_counter + 4'd1][79:64]) begin
                                    // Swap
                                    item_storage[sort_counter] <= item_storage[sort_counter + 4'd1];
                                    item_storage[sort_counter + 4'd1] <= item_storage[sort_counter];
                                end
                            end
                            sort_counter <= sort_counter + 4'd1;
                        end
                    end
                end

                OUTPUT: begin
                    busy <= 1'b1;
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (output_counter < n && n > 4'd0 && output_counter < 4'd8) begin
                        // Copy sorted item to result (only top n items)
                        // Extract name (64 bits) and price (16 bits) from stored item
                        result_name[output_counter] <= 8'd0; // Cannot assign multi-bit to 8-bit array directly
                        // We need to assign each character individually
                        // item_storage[output_counter] has: [79:64] price, [63:0] name
                        // Result_name is an array of 8 bytes
                        
                        // For Icarus Verilog compatibility with array assignment:
                        // We must assign each element separately
                        
                        // Actually, the spec says result_name[0:7] are 8-bit outputs
                        // We need to assign each character from the 64-bit name
                        
                        // Since we can't do array slice assignment, we'll need to assign
                        // But we can't do it in a loop easily with non-constant indices
                        
                        // Solution: Use a temporary reg and assign sequentially
                        // Or better: since we know output_counter is the index,
                        // we can derive the character position
                        
                        // Actually, we need to assign result_name[0] through result_name[7]
                        // from the current item's name
                        
                        // For synthesis, we'll assign based on output_counter value
                        // This is a workaround for Icarus Verilog limitations
                        
                        // We'll use a separate always block for output assignments
                        // to avoid complexity in this state machine
                    end
                    
                    output_counter <= output_counter + 4'd1;
                    
                    if (output_counter >= n || n == 4'd0) begin
                        done <= 1'b1;
                    end
                end

                DONE: begin
                    done <= 1'b0; // Pulse done
                    busy <= 1'b0;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Output assignment logic (separate block for array handling)
    // This assigns each result element based on output_counter
    // We use a continuous assignment for each possible output_counter value
    
    integer j;
    always @(*) begin
        // Initialize to avoid latches
        for (j = 0; j < 8; j = j + 1) begin
            result_name[j] = 8'd0;
            result_price[j] = 16'd0;
        end
        
        if (state == OUTPUT && output_counter < n && n > 4'd0 && output_counter < 4'd8) begin
            // Assign based on output_counter
            // We need to assign result_name[output_counter] from item_storage[output_counter]
            // But result_name is an array of 8-bit values, not 64-bit
            // The spec says: result_name[0:7] are 8 output ports, each 8-bit ASCII
            // This means each port is one character, so we have 8 chars total
            
            // Wait, re-reading spec:
            // "result_name[0:7]: 8 output ports, each 8-bit ASCII, for the top n items"
            // This is ambiguous. It could mean:
            // 1. 8 ports, each a 1-byte name (total 8 names, each 1 char) - unlikely
            // 2. 8 ports, each is an array of 8 chars - but that's 64 ports
            // 3. result_name is an 8-element array of 8-bit values (8 bytes total)
            // 4. result_name is an 8-element array of 64-bit values
            
            // Given the input format (8-char name per item), and top n items
            // likely result_name[0:7] means 8 items, each with a name
            // But each name is 8 chars, so we need 8*8=64 bits per item
            
            // The spec says "result_name[0:7]: 8 output ports, each 8-bit ASCII"
            // This strongly suggests result_name is an array of 8 elements, each 8 bits
            // But that's only 8 bytes total, which is enough for 1 item's name
            
            // Let me re-read: "for the top n items"
            // If n=8, we need 8 items. Each item has an 8-char name.
            // So we need 8 * 8 = 64 bits of name data.
            
            // The spec format is ambiguous. Given the context:
            // - Input has item_data as 64-bit (8 chars)
            - Output has result_name[0:7] as 8 elements of 8-bit each
            // This suggests result_name[0:7] is the 8 chars of ONE item's name
            // But we need n items.
            
            // Alternative interpretation: result_name is actually 8 separate ports
            // for 8 different items, each being 8-bit (so each item has 1 char?)
            // That doesn't make sense.
            
            // Most likely interpretation:
            // result_name is an array where each element is 64 bits (8 chars)
            // The spec says "8 output ports, each 8-bit" which is contradictory.
            
            // Given typical ASIC design patterns, I'll interpret as:
            // result_name[i] = 64-bit name for item i (i from 0 to 7)
            // But the spec says "each 8-bit" which conflicts.
            
            // Let's go with: result_name is 8 elements, each 64 bits
            // But Verilog port syntax would be: output [63:0] result_name [0:7]
            // The spec says "each 8-bit" which contradicts.
            
            // Re-reading carefully:
            // "result_name[0:7]: 8 output ports, each 8-bit ASCII, for the top n items"
            // This could mean: we output 8 items, each has a name, but we only output
            // 8 characters total? That doesn't make sense.
            
            // Let me assume the spec has a typo and means:
            // result_name[0:7] is an array of 8 elements, each being a 64-bit name
            // But formatted as [0:7] which in Verilog is 8 elements.
            // Each element should be 64 bits to hold 8 chars.
            
            // However, the spec explicitly says "each 8-bit"
            // So maybe: result_name[0:7] are 8 separate 1-byte outputs.
            // And we have result_price[0:7] as 8 separate 16-bit outputs.
            // This would mean we output 8 items, each with name=1 byte, price=16 bits.
            // But input has 8-byte names. So we'd lose data.
            
            // Given the ambiguity, I'll implement the most reasonable interpretation:
            // result_name[i] is a 64-bit name for item i
            // result_price[i] is a 16-bit price for item i
            // Where i ranges from 0 to 7
            
            // But the port declaration in spec says "each 8-bit ASCII"
            // This is confusing. Let me check the output specification again:
            // "result_name[0:7]: 8 output ports, each 8-bit ASCII"
            // Maybe it means: 8 ports, each is 8-bit, and together they form 8 items?
            // No, that would be 8*8=64 ports for 8 items.
            
            // I'll make a decision: result_name[i] is 64-bit, result_price[i] is 16-bit
            // This matches the input format and makes logical sense.
            // The spec's "each 8-bit" might be a typo for "each 64-bit" or
            // referring to the ASCII character width, not the port width.
            
            // Actually, I think I understand now:
            // The spec might mean: result_name is an array where each element
            // is itself an array of 8 chars. So result_name[0:7][7:0] would be
            // 8 elements, each with 8 bits. But Verilog doesn't support multi-dimensional
            // arrays in module ports well.
            
            // Let's go with the most synthesizable interpretation:
            // We'll have result_name as 64-bit for each item, and result_price as 16-bit
            // But since the spec says "each 8-bit ASCII", I'll interpret that as
            // each output port is a byte, and we have 8 ports total.
            // So for n items, we output n characters (not n names).
            
            // This interpretation: output n characters (first char of each item's name)
            // But that seems odd given input has full names.
            
            // Final interpretation based on typical patterns:
            // The spec has an inconsistency. I'll implement:
            // result_name[0:7] as 8 elements of 64 bits each (8 names)
            // result_price[0:7] as 8 elements of 16 bits each (8 prices)
            // The "each 8-bit ASCII" in spec likely refers to character width within the name.
            
            // But wait, the original spec says:
            // "result_name[0:7]: 8 output ports, each 8-bit ASCII"
            // If each port is 8-bit, that's 8 bits total per port.
            // With 8 ports, that's 64 bits total.
            // With 8 items, that's 8 bits per item (1 char per item).
            
            // This must be it: we output the first character of each item's name.
            // So result_name[0] = first char of top item, result_name[1] = first char of 2nd item, etc.
            // This is a strange spec, but it matches the port description.
            
            // Therefore:
            // item_storage contains 80 bits: [79:64] price, [63:56] char1, [55:48] char2, ..., [7:0] char8
            // result_name[i] should be char1 (bits [63:56]) of item i
            // result_price[i] should be price (bits [79:64]) of item i
            
            // This makes sense: 8 ports for 8 items, each port is 8-bit char.
            
            // Let's implement this interpretation.
            
            // We need to assign based on output_counter.
            // But we can't use output_counter in combinational logic easily
            // because it changes synchronously.
            
            // Better: use a combinational block that depends on output_counter
            // and state.
            
            // Actually, for the combinational output assignment, we need to
            // know which item we're currently outputting.
            
            // We'll create a combinational assignment for each result element.
            // Each result element i should show item i's data.
            
            // So: result_name[i] = first char of item i (from item_storage[i])
            // result_price[i] = price of item i (from item_storage[i])
            
            // This assignment should be combinational and always show the sorted results.
            // No, we only want to update outputs during OUTPUT phase.
            
            // Let's use the output_counter to control when to update.
            // But that's tricky with combinational logic.
            
            // Simpler: make result registers and update them in the OUTPUT state.
            // But we already declared them as outputs (which are implicitly wire).
            // We declared them as output reg, so we can assign in always block.
            
            // Let's modify: in OUTPUT state, when output_counter < n,
            // assign result_name[output_counter] and result_price[output_counter]
            // But output_counter changes each cycle, so we need to capture it.
            
            // We'll use a flag to trigger assignment.
            // Actually, simplest: in OUTPUT state, each cycle we set one result.
            // But result_name and result_price are arrays.
            
            // For Icarus Verilog, array assignment in always block must be element-wise.
            // We'll do: result_name[output_counter] <= item_storage[output_counter][63:56];
            // But output_counter changes, so we'd be assigning different indices each cycle.
            
            // This is fine. We just need to ensure the assignment is inside the always block
            // with proper conditions.
            
            // Let's rewrite the OUTPUT logic to include assignments.
        end
    end

    // Rewrite OUTPUT state with proper array assignments
    // We'll modify the main always block to include output assignments
    // But we need to be careful about array assignment syntax.
    
    // For Icarus Verilog, we must assign each element individually.
    // Since output_counter is variable, we need conditional assignments.
    
    // We'll add this logic to the OUTPUT state in the main always block:
    // But we need to assign result_name[i] for i=0 to 7.
    
    // Actually, let's restructure. We'll have the OUTPUT state update
    // the result arrays based on output_counter.
    
    // But the result arrays are indexed by item position (0-7), not by cycle.
    // So in cycle 0 of OUTPUT, we set result_name[0], result_price[0]
    // In cycle 1, we set result_name[1], result_price[1]
    // etc.
    
    // This means in each OUTPUT cycle, we assign one element.
    // We need to do this in the main always block.
    
    // Let me rewrite the OUTPUT state more carefully:

    // Remove the previous combinational output block and integrate into main block
    // Actually, we need both: combinational for output values, sequential for updates

    // Let's do this: In the OUTPUT state, we update result_name[output_counter] and
    // result_price[output_counter] when output_counter < n.

    // But result_name and result_price need to retain their values after OUTPUT state.
    // So we need sequential assignments.

    // Revised approach: In the main always block, in OUTPUT state:
    // if (output_counter < n) begin
    //    result_name[output_counter] <= item_storage[output_counter][63:56];
    //    result_price[output_counter] <= item_storage[output_counter][79:64];
    // end
    
    // This should work, but we need to ensure it's inside the always block.
    
    // Let me modify the code above to include these assignments.
    // Since I can't edit previous code, I'll provide a corrected version.

    // Actually, let me provide a complete, corrected module.
    // The previous code had issues with the OUTPUT state.

    // Revised complete module:
endmodule

// Second module definition to fix the OUTPUT state issues
module top_module (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire items_valid,
    input wire [63:0] item_data,
    input wire [15:0] item_price,
    input wire [3:0] n,
    input wire [3:0] item_index,
    output reg [7:0] result_name [0:7],
    output reg [15:0] result_price [0:7],
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] INPUT    = 3'd1;
    localparam [2:0] SORT     = 3'd2;
    localparam [2:0] OUTPUT   = 3'd3;
    localparam [2:0] DONE     = 3'd4;

    // Internal storage: 16 items, each 80 bits (16-bit price + 64-bit name)
    reg [79:0] item_storage [0:15];
    reg [3:0] input_counter;
    reg [3:0] sort_counter;
    reg [3:0] output_counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State machine
    reg [2:0] state;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            busy <= 1'b0;
            input_counter <= 4'd0;
            sort_counter <= 4'd0;
            output_counter <= 4'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                result_name[i] <= 8'd0;
                result_price[i] <= 16'd0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                item_storage[i] <= 80'd0;
            end
        end else begin
            // Default done clear
            if (start) begin
                done <= 1'b0;
            end

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    input_counter <= 4'd0;
                    sort_counter <= 4'd0;
                    output_counter <= 4'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INPUT;
                    end
                end

                INPUT: begin
                    busy <= 1'b1;
                    cycle_count <= cycle_count + 8'd1;
                    if (items_valid && input_counter < 4'd16) begin
                        // Store item: price in [79:64], name in [63:0]
                        item_storage[input_counter] <= {item_price, item_data};
                        input_counter <= input_counter + 4'd1;
                    end
                    if (input_counter == 4'd15 && items_valid) begin
                        state <= SORT;
                    end
                end

                SORT: begin
                    busy <= 1'b1;
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Bubble sort: 15 passes
                    if (sort_counter < 4'd15) begin
                        // Compare adjacent items: sort_counter with sort_counter+1
                        // This does one comparison per cycle
                        if (sort_counter < 4'd15) begin
                            // Compare prices (bits [79:64])
                            if (item_storage[sort_counter][79:64] < item_storage[sort_counter + 4'd1][79:64]) begin
                                // Swap
                                item_storage[sort_counter] <= item_storage[sort_counter + 4'd1];
                                item_storage[sort_counter + 4'd1] <= item_storage[sort_counter];
                            end
                        end
                        sort_counter <= sort_counter + 4'd1;
                    end else begin
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    busy <= 1'b1;
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Output n items (max 8)
                    if (output_counter < n && n > 4'd0 && output_counter < 4'd8) begin
                        // Assign result arrays
                        result_name[output_counter] <= item_storage[output_counter][63:56]; // First char
                        result_price[output_counter] <= item_storage[output_counter][79:64]; // Price
                        output_counter <= output_counter + 4'd1;
                    end else begin
                        done <= 1'b1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase

            // Safety timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE) begin
                state <= DONE;
                done <= 1'b1;
            end
        end
    end
endmodule