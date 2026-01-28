module bid_checker(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [31:0] data_in,
    input [3:0] idx_in,
    input we,
    output reg [31:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] FINISH    = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [31:0] internal_ram [0:15];
    reg [3:0] current_idx;
    reg [31:0] ref_core;
    reg [31:0] current_val;
    reg [31:0] temp_val;
    reg [31:0] remainder;
    reg [31:0] quotient;
    reg [5:0] div_cycle;
    reg [5:0] norm_cycle;
    reg [7:0] cycle_count;
    reg fail_flag;
    reg div_by_2_done;
    reg div_by_3_done;
    reg norm_done;
    reg [3:0] element_idx;
    reg [31:0] core_val;

    // Constants
    localparam [7:0] MAX_CYCLES = 8'd2000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_idx <= 4'd0;
            ref_core <= 32'd0;
            current_val <= 32'd0;
            temp_val <= 32'd0;
            remainder <= 32'd0;
            quotient <= 32'd0;
            div_cycle <= 6'd0;
            norm_cycle <= 6'd0;
            cycle_count <= 8'd0;
            fail_flag <= 1'b0;
            div_by_2_done <= 1'b0;
            div_by_3_done <= 1'b0;
            norm_done <= 1'b0;
            element_idx <= 4'd0;
            core_val <= 32'd0;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 32'd0;
            
            // Initialize internal RAM
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                internal_ram[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (we) begin
                        internal_ram[idx_in] <= data_in;
                    end
                    if (start) begin
                        next_state <= COMPUTE;
                        element_idx <= 4'd0;
                        fail_flag <= 1'b0;
                        cycle_count <= 8'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                        fail_flag <= 1'b1;
                    end else begin
                        if (element_idx == 4'd0) begin
                            // First element: compute reference core
                            if (!norm_done) begin
                                // Normalize the first element
                                temp_val <= internal_ram[0];
                                norm_cycle <= 6'd0;
                                div_by_2_done <= 1'b0;
                                div_by_3_done <= 1'b0;
                                norm_done <= 1'b0;
                            end else begin
                                ref_core <= core_val;
                                element_idx <= element_idx + 4'd1;
                                norm_done <= 1'b0;
                            end
                        end else if (element_idx < len) begin
                            // Process next element
                            if (!norm_done) begin
                                temp_val <= internal_ram[element_idx];
                                norm_cycle <= 6'd0;
                                div_by_2_done <= 1'b0;
                                div_by_3_done <= 1'b0;
                                norm_done <= 1'b0;
                            end else begin
                                if (core_val != ref_core) begin
                                    fail_flag <= 1'b1;
                                end
                                element_idx <= element_idx + 4'd1;
                                norm_done <= 1'b0;
                            end
                        end else begin
                            // All elements processed
                            next_state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    valid <= ~fail_flag;
                    result <= ref_core;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end

    // Normalization logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_by_2_done <= 1'b0;
            div_by_3_done <= 1'b0;
            norm_done <= 1'b0;
        end else if (state == COMPUTE && !norm_done) begin
            if (!div_by_2_done) begin
                // Check if divisible by 2
                if (temp_val[0] == 1'b0) begin
                    temp_val <= temp_val >> 1;
                end else begin
                    div_by_2_done <= 1'b1;
                end
            end else if (!div_by_3_done) begin
                // Check if divisible by 3 using restoring division
                if (div_cycle == 6'd0) begin
                    remainder <= 32'd0;
                    quotient <= 32'd0;
                end
                
                if (div_cycle < 6'd32) begin
                    // Shift left
                    remainder <= {remainder[30:0], temp_val[31]};
                    temp_val <= {temp_val[30:0], 1'b0};
                    
                    // Subtract divisor (3)
                    remainder <= remainder - 32'd3;
                    
                    if (remainder[31]) begin
                        // Restore if negative
                        remainder <= remainder + 32'd3;
                        temp_val[0] <= 1'b0;
                    end else begin
                        temp_val[0] <= 1'b1;
                    end
                    
                    div_cycle <= div_cycle + 6'd1;
                end else begin
                    // Division complete
                    if (remainder == 32'd0) begin
                        temp_val <= quotient;
                        div_cycle <= 6'd0;
                    end else begin
                        div_by_3_done <= 1'b1;
                    end
                end
            end else begin
                // Normalization complete
                core_val <= temp_val;
                norm_done <= 1'b1;
            end
        end
    end

endmodule