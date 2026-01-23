module gold_scheduler (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] t0, h0, t1, h1, t2, h2, t3, h3,
    input wire [7:0] t4, h4, t5, h5, t6, h6, t7, h7,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] SORT      = 3'd2;
    localparam [2:0] SELECT    = 3'd3;
    localparam [2:0] FINISH    = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Internal registers for storing inputs
    reg [7:0] t_reg [0:7];
    reg [7:0] h_reg [0:7];
    
    // Sorting variables
    reg [3:0] i, j;
    reg [7:0] temp_t, temp_h;
    
    // Selection variables
    reg [7:0] selected_t [0:7];
    reg [3:0] count;
    reg [15:0] total_time;
    
    // Max finding variables
    reg [7:0] max_t;
    reg [3:0] max_index;
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all registers
            integer k;
            for (k = 0; k < 8; k = k + 1) begin
                t_reg[k] <= 8'd0;
                h_reg[k] <= 8'd0;
                selected_t[k] <= 8'd0;
            end
            count <= 4'd0;
            total_time <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            temp_t <= 8'd0;
            temp_h <= 8'd0;
            max_t <= 8'd0;
            max_index <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD: begin
                    // Load inputs into internal registers
                    t_reg[0] <= t0; h_reg[0] <= h0;
                    t_reg[1] <= t1; h_reg[1] <= h1;
                    t_reg[2] <= t2; h_reg[2] <= h2;
                    t_reg[3] <= t3; h_reg[3] <= h3;
                    t_reg[4] <= t4; h_reg[4] <= h4;
                    t_reg[5] <= t5; h_reg[5] <= h5;
                    t_reg[6] <= t6; h_reg[6] <= h6;
                    t_reg[7] <= t7; h_reg[7] <= h7;
                    
                    // Initialize selection variables
                    count <= 4'd0;
                    total_time <= 16'd0;
                    integer k;
                    for (k = 0; k < 8; k = k + 1) begin
                        selected_t[k] <= 8'd0;
                    end
                    
                    // Initialize sorting variables
                    i <= 4'd0;
                    j <= 4'd0;
                    
                    next_state <= SORT;
                end
                
                SORT: begin
                    // Bubble sort implementation
                    if (i < 7) begin
                        if (j < 7 - i) begin
                            // Compare h_reg[j] and h_reg[j+1]
                            if (h_reg[j] > h_reg[j+1]) begin
                                // Swap t and h
                                temp_t <= t_reg[j];
                                temp_h <= h_reg[j];
                                t_reg[j] <= t_reg[j+1];
                                h_reg[j] <= h_reg[j+1];
                                t_reg[j+1] <= temp_t;
                                h_reg[j+1] <= temp_h;
                            end
                            j <= j + 1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 1;
                        end
                    end else begin
                        // Sorting complete
                        i <= 4'd0;
                        j <= 4'd0;
                        next_state <= SELECT;
                    end
                end
                
                SELECT: begin
                    // Selection algorithm
                    if (i < 8) begin
                        // Check if current pair is valid (t != 255 or h != 0)
                        if (t_reg[i] != 8'd255 || h_reg[i] != 8'd0) begin
                            // Check if we can add this store
                            if (total_time + t_reg[i] <= h_reg[i]) begin
                                // Add this store
                                selected_t[count] <= t_reg[i];
                                total_time <= total_time + t_reg[i];
                                count <= count + 1;
                            end else if (count > 0) begin
                                // Find max_t in selected_t
                                max_t <= selected_t[0];
                                max_index <= 4'd0;
                                integer k;
                                for (k = 1; k < count; k = k + 1) begin
                                    if (selected_t[k] > max_t) begin
                                        max_t <= selected_t[k];
                                        max_index <= k;
                                    end
                                end
                                
                                // Replace if beneficial
                                if (max_t > t_reg[i]) begin
                                    total_time <= total_time - max_t + t_reg[i];
                                    selected_t[max_index] <= t_reg[i];
                                end
                            end
                        end
                        i <= i + 1;
                    end else begin
                        // Selection complete
                        i <= 4'd0;
                        result <= count;
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Cycle counter to prevent infinite loops
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 8'd1;
            end else begin
                next_state <= IDLE;
                done <= 1'b0;
            end
        end
    end
    
    // Combinational logic for max finding (used in SELECT state)
    always @(*) begin
        if (state == SELECT && i < 8 && count > 0) begin
            max_t = selected_t[0];
            max_index = 4'd0;
            integer k;
            for (k = 1; k < count; k = k + 1) begin
                if (selected_t[k] > max_t) begin
                    max_t = selected_t[k];
                    max_index = k;
                end
            end
        end
    end

endmodule