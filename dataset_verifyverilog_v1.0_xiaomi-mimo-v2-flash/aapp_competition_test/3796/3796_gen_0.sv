module beautiful_rectangle(
    input clk, rst_n,
    input start,
    input [3:0] len_in,
    input [31:0] data_in,
    input data_valid,
    input data_last,
    output reg [15:0] result_area,
    output reg [7:0] result_h, result_w,
    output reg done,
    output reg [31:0] out_data,
    output reg out_valid,
    output reg [7:0] out_x, out_y
);
    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] READ_INPUT = 3'd1;
    localparam [2:0] SORT_COUNTS = 3'd2;
    localparam [2:0] FIND_RECT  = 3'd3;
    localparam [2:0] FILL_GRID  = 3'd4;
    localparam [2:0] OUTPUT     = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;
    
    reg [2:0] state;
    reg [11:0] input_counter;
    reg [11:0] input_total;
    reg [15:0] freq_ram [0:4095];
    reg [31:0] value_ram [0:4095];
    reg [31:0] grid [0:63][0:63];
    
    // Sorting network signals
    reg [5:0] sort_freq [0:15];
    reg [31:0] sort_val [0:15];
    reg [3:0] sort_stage;
    reg [3:0] sort_pair;
    
    // Optimization variables
    reg [6:0] opt_h;
    reg [15:0] opt_total;
    reg [15:0] opt_w;
    reg [15:0] best_area;
    reg [7:0] best_h;
    reg [7:0] best_w;
    reg [6:0] opt_i;
    
    // Grid filling variables
    reg [6:0] fill_r;
    reg [6:0] fill_c;
    reg [5:0] fill_idx;
    reg [5:0] fill_usage [0:15];
    reg [5:0] fill_count;
    
    // Output streaming
    reg [6:0] out_r;
    reg [6:0] out_c;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Helper function to clamp
    function [15:0] clamp16;
        input [31:0] v;
        begin
            if (v > 16'hFFFF)
                clamp16 = 16'hFFFF;
            else
                clamp16 = v[15:0];
        end
    endfunction
    
    integer i, j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_area <= 16'd0;
            result_h <= 8'd0;
            result_w <= 8'd0;
            done <= 1'b0;
            out_data <= 32'd0;
            out_valid <= 1'b0;
            out_x <= 8'd0;
            out_y <= 8'd0;
            input_counter <= 12'd0;
            input_total <= 12'd0;
            sort_stage <= 4'd0;
            sort_pair <= 4'd0;
            opt_h <= 7'd0;
            opt_i <= 7'd0;
            best_area <= 16'd0;
            best_h <= 8'd0;
            best_w <= 8'd0;
            fill_r <= 7'd0;
            fill_c <= 7'd0;
            fill_idx <= 6'd0;
            fill_count <= 6'd0;
            out_r <= 7'd0;
            out_c <= 7'd0;
            cycle_counter <= 8'd0;
            
            for (i = 0; i < 16; i = i + 1) begin
                sort_freq[i] <= 6'd0;
                sort_val[i] <= 32'd0;
                fill_usage[i] <= 6'd0;
            end
            
            for (i = 0; i < 4096; i = i + 1) begin
                freq_ram[i] <= 16'd0;
                value_ram[i] <= 32'd0;
            end
            
            for (i = 0; i < 64; i = i + 1) begin
                for (j = 0; j < 64; j = j + 1) begin
                    grid[i][j] <= 32'd0;
                end
            end
        end else begin
            done <= 1'b0;
            out_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    cycle_counter <= 8'd0;
                    if (start) begin
                        state <= READ_INPUT;
                        input_counter <= 12'd0;
                        input_total <= {8'd0, len_in};
                    end
                end
                
                READ_INPUT: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (data_valid) begin
                        if (input_counter < 4095) begin
                            value_ram[input_counter] <= data_in;
                            freq_ram[data_in[11:0]] <= freq_ram[data_in[11:0]] + 16'd1;
                            input_counter <= input_counter + 12'd1;
                        end
                        if (data_last) begin
                            state <= SORT_COUNTS;
                            sort_stage <= 4'd0;
                            sort_pair <= 4'd0;
                            
                            // Load top 16 frequencies
                            for (i = 0; i < 16; i = i + 1) begin
                                sort_freq[i] <= 6'd0;
                                sort_val[i] <= 32'd0;
                            end
                        end
                    end
                end
                
                SORT_COUNTS: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Simple bubble sort on 16 elements
                    if (sort_pair < 15) begin
                        if (sort_freq[sort_pair] < sort_freq[sort_pair + 1]) begin
                            // Swap
                            sort_freq[sort_pair] <= sort_freq[sort_pair + 1];
                            sort_freq[sort_pair + 1] <= sort_freq[sort_pair];
                            sort_val[sort_pair] <= sort_val[sort_pair + 1];
                            sort_val[sort_pair + 1] <= sort_val[sort_pair];
                        end
                        sort_pair <= sort_pair + 4'd1;
                    end else begin
                        sort_pair <= 4'd0;
                        if (sort_stage < 4'd15) begin
                            sort_stage <= sort_stage + 4'd1;
                        end else begin
                            state <= FIND_RECT;
                            opt_h <= 7'd1;
                            best_area <= 16'd0;
                            best_h <= 8'd0;
                            best_w <= 8'd0;
                            opt_i <= 7'd0;
                        end
                    end
                end
                
                FIND_RECT: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Calculate total for this h
                    if (opt_i < 16) begin
                        if (sort_freq[opt_i] >= opt_h) begin
                            opt_total <= opt_total + opt_h;
                        end else begin
                            opt_total <= opt_total + sort_freq[opt_i];
                        end
                        opt_i <= opt_i + 7'd1;
                    end else begin
                        // Calculate w
                        opt_w <= opt_total / opt_h;
                        
                        if (opt_total >= opt_h * opt_h) begin
                            // Valid rectangle
                            if (opt_total / opt_h > best_area / opt_h) begin
                                best_area <= opt_total;
                                best_h <= opt_h[7:0];
                                best_w <= opt_w[7:0];
                            end
                        end
                        
                        opt_i <= 7'd0;
                        opt_total <= 16'd0;
                        
                        if (opt_h < 7'd64 && opt_h < input_counter[6:0]) begin
                            opt_h <= opt_h + 7'd1;
                        end else begin
                            state <= FILL_GRID;
                            result_area <= best_area;
                            result_h <= best_h;
                            result_w <= best_w;
                            fill_r <= 7'd0;
                            fill_c <= 7'd0;
                            fill_idx <= 6'd0;
                            fill_count <= 6'd0;
                            for (i = 0; i < 16; i = i + 1) begin
                                fill_usage[i] <= 6'd0;
                            end
                        end
                    end
                end
                
                FILL_GRID: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    if (fill_r < best_h && fill_c < best_w) begin
                        // Place value with diagonal rotation
                        grid[fill_r][fill_c] <= sort_val[fill_idx];
                        
                        // Update usage
                        fill_usage[fill_idx] <= fill_usage[fill_idx] + 6'd1;
                        
                        // Move to next value if count reached
                        if (fill_usage[fill_idx] + 6'd1 >= best_h[5:0]) begin
                            if (fill_idx < 15) begin
                                fill_idx <= fill_idx + 6'd1;
                            end
                        end
                        
                        // Move to next position
                        if (fill_c < best_w - 1) begin
                            fill_c <= fill_c + 7'd1;
                        end else begin
                            fill_c <= 7'd0;
                            fill_r <= fill_r + 7'd1;
                        end
                    end else begin
                        state <= OUTPUT;
                        out_r <= 7'd0;
                        out_c <= 7'd0;
                    end
                end
                
                OUTPUT: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    if (out_r < best_h && out_c < best_w) begin
                        out_data <= grid[out_r][out_c];
                        out_x <= out_c[7:0];
                        out_y <= out_r[7:0];
                        out_valid <= 1'b1;
                        
                        if (out_c < best_w - 1) begin
                            out_c <= out_c + 7'd1;
                        end else begin
                            out_c <= 7'd0;
                            out_r <= out_r + 7'd1;
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Safety timeout
            if (cycle_counter >= MAX_CYCLES && state != IDLE && state != DONE_STATE) begin
                state <= DONE_STATE;
            end
        end
    end
endmodule