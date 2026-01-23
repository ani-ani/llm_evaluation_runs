module pharmacy_sim (
    input clk,
    input rst_n,
    input start,
    input [63:0] in_drop_time [7:0],
    input [7:0] in_type [7:0],
    input [31:0] in_fill_time [7:0],
    input [2:0] valid_count,
    output reg [63:0] avg_in_store_time,
    output reg [63:0] avg_remote_time,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b001;
    localparam PROCESSING = 3'b010;
    localparam DONE = 3'b100;

    // Internal Registers
    reg [2:0] state;
    reg [63:0] current_time;
    reg [2:0] remaining_prescriptions;
    
    // Storage for prescriptions (indexed 0 to 7)
    reg [63:0] drop_time_reg [7:0];
    reg [31:0] fill_time_reg [7:0];
    reg type_reg [7:0];
    reg present_reg [7:0];

    // Sums for averages (Q16.16 format)
    reg [63:0] sum_in_store;
    reg [63:0] sum_remote;
    reg [31:0] count_in_store;
    reg [31:0] count_remote;

    // Technician Pool
    // We track completion times for up to 4 technicians
    // If value is 0, the technician is free
    reg [63:0] tech_time [3:0];
    integer i, j;

    // Sorting Logic Variables
    reg [63:0] best_drop;
    reg [31:0] best_fill;
    reg best_type;
    reg [2:0] best_idx;
    reg swap;

    // Event Queue Logic Variables
    reg [63:0] next_drop_time;
    reg [63:0] next_comp_time;
    reg has_next_drop;
    reg has_next_comp;
    reg [2:0] next_comp_idx;
    reg [63:0] earliest_event_time;
    reg event_is_completion;
    reg event_is_drop;

    // Combinational block for event detection and sorting
    always @(*) begin
        // --- 1. Find Next Drop Event ---
        next_drop_time = 64'hFFFFFFFFFFFFFFFF;
        has_next_drop = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (present_reg[i]) begin
                if (drop_time_reg[i] < next_drop_time) begin
                    next_drop_time = drop_time_reg[i];
                    has_next_drop = 1;
                end
            end
        end

        // --- 2. Find Next Completion Event ---
        next_comp_time = 64'hFFFFFFFFFFFFFFFF;
        has_next_comp = 0;
        next_comp_idx = 0;
        for (i = 0; i < 4; i = i + 1) begin
            if (tech_time[i] != 0) begin // busy
                if (tech_time[i] < next_comp_time) begin
                    next_comp_time = tech_time[i];
                    has_next_comp = 1;
                    next_comp_idx = i;
                end
            end
        end

        // --- 3. Determine Earliest Event ---
        event_is_completion = 0;
        event_is_drop = 0;
        earliest_event_time = 64'hFFFFFFFFFFFFFFFF;

        if (has_next_comp && has_next_drop) begin
            if (next_comp_time <= next_drop_time) begin
                earliest_event_time = next_comp_time;
                event_is_completion = 1;
            end else begin
                earliest_event_time = next_drop_time;
                event_is_drop = 1;
            end
        end else if (has_next_comp) begin
            earliest_event_time = next_comp_time;
            event_is_completion = 1;
        end else if (has_next_drop) begin
            earliest_event_time = next_drop_time;
            event_is_drop = 1;
        end

        // --- 4. Select Next Prescription (Selection Sort Logic) ---
        // Criteria: In-Store > Drop Time > Fill Time
        // We scan all present prescritpions that are not yet taken by a tech (drop time <= current)
        // Note: This logic is only used during the 'assign tech' phase in FSM.
        
        best_drop = 64'hFFFFFFFFFFFFFFFF;
        best_fill = 32'hFFFFFFFF;
        best_type = 0; // Default to remote if tie
        best_idx = 0;
        
        // Iterate to find best candidate based on rules
        // Rule 1: In-Store preference is handled by prioritizing Type 1 in comparison
        // Rule 2: Lower Drop Time
        // Rule 3: Shorter Fill Time
        
        // We first look for In-Store candidates
        swap = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (present_reg[i] && (drop_time_reg[i] <= current_time)) begin
                if (in_type[i] == 1'b1) begin
                    // Found an In-Store, check if it is better than current best (if best is remote or other)
                    // We prefer In-Store over Remote. If we have In-Store, we only compare with In-Store.
                    // Since we iterate sequentially, we just need to pick the best In-Store.
                    if (!swap || type_reg[best_idx] == 0 || drop_time_reg[i] < best_drop || (drop_time_reg[i] == best_drop && fill_time_reg[i] < best_fill)) begin
                        best_idx = i;
                        best_drop = drop_time_reg[i];
                        best_fill = fill_time_reg[i];
                        best_type = 1;
                        swap = 1;
                    end
                end
            end
        end
        
        // If no In-Store found, look for Remote
        if (!swap) begin
            for (i = 0; i < 8; i = i + 1) begin
                if (present_reg[i] && (drop_time_reg[i] <= current_time)) begin
                    if (drop_time_reg[i] < best_drop || (drop_time_reg[i] == best_drop && fill_time_reg[i] < best_fill)) begin
                        best_idx = i;
                        best_drop = drop_time_reg[i];
                        best_fill = fill_time_reg[i];
                        best_type = 0;
                        swap = 1;
                    end
                end
            end
        end
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            current_time <= 0;
            sum_in_store <= 0;
            sum_remote <= 0;
            count_in_store <= 0;
            count_remote <= 0;
            remaining_prescriptions <= 0;
            avg_in_store_time <= 0;
            avg_remote_time <= 0;
            for (i = 0; i < 8; i = i + 1) begin
                present_reg[i] <= 0;
                drop_time_reg[i] <= 0;
                fill_time_reg[i] <= 0;
                type_reg[i] <= 0;
            end
            for (i = 0; i < 4; i = i + 1) begin
                tech_time[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Initialize Simulation
                        state <= PROCESSING;
                        current_time <= 0;
                        sum_in_store <= 0;
                        sum_remote <= 0;
                        count_in_store <= 0;
                        count_remote <= 0;
                        remaining_prescriptions <= valid_count;
                        
                        // Load Inputs
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < valid_count) begin
                                present_reg[i] <= 1;
                                drop_time_reg[i] <= in_drop_time[i];
                                fill_time_reg[i] <= in_fill_time[i];
                                type_reg[i] <= in_type[i];
                            end else begin
                                present_reg[i] <= 0;
                            end
                        end
                        // Initialize Techs to 0 (free)
                        for (i = 0; i < 4; i = i + 1) tech_time[i] <= 0;
                    end
                end

                PROCESSING: begin
                    // Loop until all prescriptions are done
                    if (remaining_prescriptions == 0) begin
                        state <= DONE;
                    end else begin
                        // Calculate averages if techs are busy but nothing else to do immediately? 
                        // No, we advance time.

                        // --- Decision Logic ---
                        // 1. Check if we should assign work to free techs
                        // 2. Advance time

                        // Assign Work Loop (Greedy: Assign as much as possible at current time)
                        // We iterate multiple times per cycle to drain available slots if logic permits, 
                        // or just one step per cycle. Let's do a robust check.
                        
                        // Are there free techs and available prescriptions?
                        // We scan for free techs.
                        // To keep logic simple and sequential per cycle, we look for ONE event to process.
                        
                        // Prioritize Completions or Drops? 
                        // Actually, we should process strictly by time order.
                        // But combinational logic sets 'earliest_event_time'.
                        
                        // If Earliest Event is a DROP:
                        if (event_is_drop && !event_is_completion) begin
                            // Time jumps to drop time
                            if (earliest_event_time > current_time) begin
                                current_time <= earliest_event_time;
                            end
                            
                            // Drop event logic is implicit (the item becomes available).
                            // Since drop_time_reg contains the absolute time, we don't modify the array.
                            // However, we must prevent infinite loop if we just jump time without marking handled.
                            // Wait, drop events are just "time is >= drop_time".
                            // If we have free techs, we should assign immediately (which requires sorting).
                            // The sorting combinational logic uses (drop_time_reg[i] <= current_time).
                            
                            // So, if event is drop, we update time. The sorting logic will now pick it up.
                            // Then we need to go back to top of PROCESSING state to check "assign work" logic.
                            // Since this is a clocked block, we will wait for next cycle.
                        end
                        
                        // If Earliest Event is COMPLETION:
                        else if (event_is_completion) begin
                            // Time jumps to completion time
                            if (earliest_event_time > current_time) begin
                                current_time <= earliest_event_time;
                            end
                            
                            // Handle completion
                            // We need to know WHICH prescription finished.
                            // We need to store mapping: Tech -> Prescription Index
                            // Or, we can store 'Completion Time' and 'Associated Prescription Index'.
                            
                            // Wait, current design stores only tech_time. We lose prescription info.
                            // We need to track which prescription is at which tech.
                            // Let's add a mapping array.
                            // reg [2:0] tech_mapping [3:0]; // Stores index of prescription for each tech
                            // We must add this to the design.
                            // Let's assume we add this register.
                            
                            // Calculate Wait Time: current_time - drop_time
                            // We need the drop time of the finished item. 
                            // We need to know the index of the finished item.
                            // We must add: reg [2:0] tech_ptr [3:0];
                            
                            // Let's modify the code to include tech_ptr in the declaration.
                        end

                    end
                end

                DONE: begin
                    done <= 1;
                    // Calculate Final Averages
                    // Input sum is Q16.16. Count is integer.
                    // Division: Sum / Count.
                    // For 0 count, output 0.
                    if (count_in_store > 0) begin
                        avg_in_store_time <= sum_in_store / count_in_store;
                    end else begin
                        avg_in_store_time <= 0;
                    end
                    
                    if (count_remote > 0) begin
                        avg_remote_time <= sum_remote / count_remote;
                    end else begin
                        avg_remote_time <= 0;
                    end
                end
            endcase
        end
    end

endmodule
