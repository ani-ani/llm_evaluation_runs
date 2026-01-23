module odometer_verifier (input clk, input rst_n, // active low input start, input [7:0] num_entries, input [7:0] entry_year, input [3:0] entry_month, input [31:0] entry_odometer, input entry_valid, output reg [1:0] result, output reg done); 
// Registers 
reg [7:0] current_year, current_month; 
reg [31:0] current_odometer; 
reg [7:0] prev_year, prev_month; 
reg [31:0] prev_odometer; 
reg [7:0] entry_count; 
reg [1:0] result_reg; 
reg done_reg; 
reg tamper_flag_accum; 
reg service_violation_accum; 

// State registers 
reg [1:0] state; // IDLE=00, READ_ENTRY=01, CHECK_INTERVAL=10, VERDICT=11 
localparam IDLE = 2'b00; 
localparam READ_ENTRY = 2'b01; 
localparam CHECK_INTERVAL = 2'b10; 
localparam VERDICT = 2'b11; 

// Flags for conditions in CHECK_INTERVAL 
reg tamper_condition; 
reg service_condition; 
integer total_months, year_diff, month_diff, odometer_diff; 

always @(posedge clk) begin 
    if (!rst_n) begin 
        // Reset all registers 
        state <= IDLE; 
        entry_count <= 8'b0; 
        prev_year <= 32'd0; 
        prev_month <= 4'd0; 
        prev_odometer <= 32'd0; 
        current_year <= 8'd0; 
        current_month <= 4'd0; 
        current_odometer <= 32'd0; 
        result_reg <= 2'b00; 
        done_reg <= 1'b0; 
        tamper_flag_accum <= 1'b0; 
        service_violation_accum <= 1'b0; 
    end else begin 
        case (state) 
            IDLE: begin 
                if (start) begin 
                    state <= READ_ENTRY; 
                    entry_count <= 8'd0; // reset count 
                    // Initialize other registers as above, but in the code above, the reset block already sets them. But to be explicit: 
                    prev_year <= 32'd0; 
                    prev_month <= 4'd0; 
                    prev_odometer <= 32'd0; 
                    current_year <= 8'd0; 
                    current_month <= 4'd0; 
                    current_odometer <= 32'd0; 
                    tamper_flag_accum <= 1'b0; 
                    service_violation_accum <= 1'b0; 
                end 
            end 
            READ_ENTRY: begin 
                // Capture current entry data 
                current_year <= entry_year; 
                current_month <= entry_month; 
                current_odometer <= entry_odometer; 
                entry_count <= entry_count + 1; // increment count 

                // Check if entry_count exceeds num_entries? Clamp? 
                if (entry_count > num_entries) begin 
                    entry_count <= num_entries; 
                end

                if (entry_count == 1) begin 
                    // First entry: save to prev 
                    prev_year <= current_year; 
                    prev_month <= current_month; 
                    prev_odometer <= current_odometer; 
                    if (entry_count < num_entries) begin 
                        state <= READ_ENTRY; 
                    end else begin 
                        state <= VERDICT; 
                    end 
                end else begin 
                    // Subsequent entry, proceed to CHECK_INTERVAL 
                    state <= CHECK_INTERVAL; 
                end 
            end 
            CHECK_INTERVAL: begin 
                // Calculate differences 
                year_diff = current_year - prev_year; 
                month_diff = current_month - prev_month; 
                total_months = year_diff * 12 + month_diff; 

                if (current_odometer < prev_odometer) begin 
                    odometer_diff = current_odometer - prev_odometer + 100000; 
                end else begin 
                    odometer_diff = current_odometer - prev_odometer; 
                end 

                // Determine tamper condition 
                if (total_months == 0) begin 
                    tamper_condition = (current_odometer < prev_odometer); 
                end else begin 
                    // Check if odometer_diff is outside allowed range per month 
                    if (odometer_diff < (2000 * total_months) || odometer_diff > (20000 * total_months)) begin 
                        tamper_condition = 1'b1; 
                    end else begin 
                        tamper_condition = 1'b0; 
                    end 
                end 

                // Determine service condition 
                service_condition = (odometer_diff > 30000) || (total_months > 12); 

                // Accumulate flags 
                tamper_flag_accum <= tamper_flag_accum | tamper_condition; 
                service_violation_accum <= service_violation_accum | service_condition; 

                // Update previous entry to current for next comparison 
                prev_year <= current_year; 
                prev_month <= current_month; 
                prev_odometer <= current_odometer; 

                // Move to next state 
                if (entry_count < num_entries) begin 
                    state <= READ_ENTRY; 
                end else begin 
                    state <= VERDICT; 
                end 
            end 
            VERDICT: begin 
                // Determine result 
                if (tamper_flag_accum) begin 
                    result_reg <= 2'b10; 
                end else if (service_violation_accum) begin 
                    result_reg <= 2'b01; 
                end else begin 
                    result_reg <= 2'b00; 
                end 
                done_reg <= 1'b1; 
                // Stay in VERDICT state 
                state <= VERDICT; 
            end 
            default: state <= IDLE; 
        endcase 
    end 
endmodule 
