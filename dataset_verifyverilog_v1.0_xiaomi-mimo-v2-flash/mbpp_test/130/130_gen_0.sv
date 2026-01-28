module find_max_frequency (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [3:0] len,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] SCAN    = 3'd1;
    localparam [2:0] COUNT   = 3'd2;
    localparam [2:0] COMPARE = 3'd3;
    localparam [2:0] DONE    = 3'd4;
    
    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] scan_idx;
    reg [3:0] count_idx;
    reg [3:0] compare_idx;
    reg [3:0] num_unique;
    reg [7:0] unique_values [0:15];
    reg [3:0] frequencies [0:15];
    reg [3:0] max_freq;
    reg [7:0] max_value;
    reg [3:0] cycle_count;
    reg start_delayed;
    reg start_pulse;
    
    integer i;
    
    // Detect 1-cycle start pulse
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_delayed <= 1'b0;
            start_pulse <= 1'b0;
        end else begin
            start_delayed <= start;
            start_pulse <= start & ~start_delayed;
        end
    end
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start_pulse && (len > 4'd0)) begin
                    next_state = SCAN;
                end else if (start_pulse && (len == 4'd0)) begin
                    next_state = DONE;
                end else begin
                    next_state = IDLE;
                end
            end
            
            SCAN: begin
                if (scan_idx >= len) begin
                    next_state = COUNT;
                end else begin
                    next_state = SCAN;
                end
            end
            
            COUNT: begin
                if (count_idx >= num_unique) begin
                    next_state = COMPARE;
                end else begin
                    next_state = COUNT;
                end
            end
            
            COMPARE: begin
                if (compare_idx >= num_unique) begin
                    next_state = DONE;
                end else begin
                    next_state = COMPARE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            scan_idx <= 4'd0;
            count_idx <= 4'd0;
            compare_idx <= 4'd0;
            num_unique <= 4'd0;
            max_freq <= 4'd0;
            max_value <= 8'd0;
            cycle_count <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                unique_values[i] <= 8'd0;
                frequencies[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (next_state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 8'd0;
                    cycle_count <= 4'd0;
                    if (start_pulse && (len > 4'd0)) begin
                        scan_idx <= 4'd0;
                        num_unique <= 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            unique_values[i] <= 8'd0;
                            frequencies[i] <= 4'd0;
                        end
                    end else if (start_pulse && (len == 4'd0)) begin
                        result <= 8'd0;
                        done <= 1'b1;
                    end
                end
                
                SCAN: begin
                    // Check if value already exists
                    if (scan_idx < len) begin
                        reg found;
                        found = 1'b0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (!found && (i < num_unique)) begin
                                if (unique_values[i] == arr[scan_idx]) begin
                                    found = 1'b1;
                                end
                            end
                        end
                        
                        if (!found) begin
                            unique_values[num_unique] <= arr[scan_idx];
                            num_unique <= num_unique + 4'd1;
                        end
                        scan_idx <= scan_idx + 4'd1;
                    end
                end
                
                COUNT: begin
                    if (count_idx < num_unique) begin
                        reg [3:0] freq;
                        freq = 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < len) begin
                                if (arr[i] == unique_values[count_idx]) begin
                                    freq = freq + 4'd1;
                                end
                            end
                        end
                        frequencies[count_idx] <= freq;
                        count_idx <= count_idx + 4'd1;
                    end
                end
                
                COMPARE: begin
                    if (compare_idx < num_unique) begin
                        if (frequencies[compare_idx] > max_freq) begin
                            max_freq <= frequencies[compare_idx];
                            max_value <= unique_values[compare_idx];
                        end
                        compare_idx <= compare_idx + 4'd1;
                    end
                end
                
                DONE: begin
                    result <= max_value;
                    done <= 1'b1;
                    // Reset indices for next operation
                    scan_idx <= 4'd0;
                    count_idx <= 4'd0;
                    compare_idx <= 4'd0;
                    max_freq <= 4'd0;
                    max_value <= 8'd0;
                    num_unique <= 4'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        unique_values[i] <= 8'd0;
                        frequencies[i] <= 4'd0;
                    end
                end
                
                default: begin
                    // Should not reach here
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule