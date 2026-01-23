module table_counter (
    input clk,
    input rst_n,
    input start,
    input [9:0] query_low,
    input [9:0] query_high,
    output reg [15:0] count,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam FETCH_START = 3'b001;
    localparam COMPUTE_ROW = 3'b010;
    localparam NEXT_ROW = 3'b011;
    localparam DONE = 3'b100;

    // Internal registers
    reg [2:0] current_state;
    reg [2:0] next_state;
    reg [3:0] row_idx;      // Rows 1 to 16 (0 to 15 internally)
    reg [3:0] col_idx;      // Columns 1 to 16 (0 to 15 internally)
    reg [11:0] val;         // Current value in sequence
    reg [11:0] next_val;    // Computed next value
    reg [15:0] count_reg;   // Accumulated count
    reg count_en;           // Enable counting for current value

    // Combinational logic for reverse decimal function
    // Handles up to 3 digits (max val < 1024)
    function automatic [11:0] rev_decimal;
        input [11:0] num;
        integer temp;
        integer reversed;
        integer remainder;
        begin
            temp = num;
            reversed = 0;
            // Loop unrolls automatically or synthesizes to small logic
            // Extract digits
            if (temp >= 100) begin
                reversed = (temp % 10) * 100;
                temp = temp / 10;
                reversed = reversed + ((temp % 10) * 10);
                temp = temp / 10;
                reversed = reversed + temp;
            end else if (temp >= 10) begin
                reversed = (temp % 10) * 10;
                temp = temp / 10;
                reversed = reversed + temp;
            end else begin
                reversed = temp;
            end
            rev_decimal = reversed;
        end
    endfunction

    // Combinational logic for range check
    wire in_range;
    assign in_range = (val >= query_low) && (val <= query_high);

    // State Transition Logic (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic and Datapath (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_idx <= 4'd0;
            col_idx <= 4'd0;
            val <= 12'd0;
            count_reg <= 16'd0;
            done <= 1'b0;
        end else begin
            // Default outputs
            done <= 1'b0;
            
            case (current_state)
                IDLE: begin
                    if (start) begin
                        count_reg <= 16'd0;
                    end
                end

                FETCH_START: begin
                    // Load start value for the row: val = row_idx + 1
                    val <= row_idx + 1;
                    col_idx <= 4'd0; // Reset column counter
                end

                COMPUTE_ROW: begin
                    // Check range of current 'val'
                    if (in_range) begin
                        count_reg <= count_reg + 1'b1;
                    end

                    // Compute next value for the next cycle
                    val <= next_val;
                    
                    // Increment column counter
                    col_idx <= col_idx + 1'b1;
                end

                NEXT_ROW: begin
                    // Increment row counter
                    row_idx <= row_idx + 1'b1;
                end

                DONE: begin
                    done <= 1'b1;
                    count <= count_reg;
                end
            endcase
        end
    end

    // Next State Logic (Combinational)
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = FETCH_START;
                else
                    next_state = IDLE;
            end

            FETCH_START: begin
                // We loaded val = row_idx + 1.
                // Note: The sequence usually starts with i (val). 
                // Depending on strict interpretation, we might count 'i' or start generating from 'i'.
                // The requirement says: "In COMPUTE_ROW, compute next_val = val + rev(val). If val is in [query_low, query_high], increment count."
                // This implies we check 'val' in COMPUTE_ROW. 
                // To count the starting number (e.g. 1 for row 1), we enter COMPUTE_ROW with val=1.
                next_state = COMPUTE_ROW;
            end

            COMPUTE_ROW: begin
                // We have just processed 'col_idx' (0 to 15).
                // The loop should run 16 times per row.
                // If col_idx was 15 (incremented in this state), we are done with the row.
                // Wait, the logic above increments col_idx in COMPUTE_ROW.
                // If we start col_idx=0, we process val (start value), then increment to 1.
                // We need 16 iterations. Range of col_idx: 0 to 15.
                // Let's define: Process val, then check if done.
                // Actually, usually: Check range of 'current' val. Then compute next.
                // The state machine triggers on clock. 
                // Let's trace: FETCH_START -> val=start. Next clk -> COMPUTE_ROW.
                // Inside COMPUTE_ROW: Check val, Compute next_val, Inc col_idx.
                // Next clk: Check val (now next_val), etc.
                // We need 16 values. Let's say start value is the 1st.
                // So we need col_idx 0..15.
                // If col_idx < 15 (before increment) we stay.
                // Let's adjust logic slightly to be precise.
                
                // Logic check:
                // col_idx counts how many steps generated AFTER start?
                // Let's assume col_idx tracks iterations 0 to 15.
                if (col_idx < 15)
                    next_state = COMPUTE_ROW;
                else
                    next_state = NEXT_ROW;
            end

            NEXT_ROW: begin
                if (row_idx < 15) // rows 0..15 (1..16 total)
                    next_state = FETCH_START;
                else
                    next_state = DONE;
            end

            DONE: begin
                next_state = IDLE; // Self-reset or wait for start to reset internally
            end

            default: next_state = IDLE;
        endcase
    end

    // Combinational Logic for Next Value Calculation
    // Required to be available for the sequential update in COMPUTE_ROW
    always @(*) begin
        next_val = val + rev_decimal(val);
    end

    // Output Assignment for count
    // Registered in DONE state, but ensuring output is driven
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 16'd0;
        end else if (current_state == DONE) begin
            count <= count_reg;
        end
    end

endmodule
