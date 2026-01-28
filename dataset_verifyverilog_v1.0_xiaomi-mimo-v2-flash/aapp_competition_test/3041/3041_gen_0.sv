module ticket_purchasing (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] trip_zone,
    input wire [31:0] trip_time,
    input wire trip_valid,
    input wire trip_done,
    output reg ready,
    output reg [15:0] min_cost,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] FETCH      = 3'd1;
    localparam [2:0] CALC       = 3'd2;
    localparam [2:0] WRITE      = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    localparam [2:0] ERROR      = 3'd5;
    
    // Constants
    localparam [31:0] MAX_TRIPS     = 32'd1000;
    localparam [31:0] VALIDITY_TIME = 32'd10000;
    localparam [3:0]  MAX_ZONE      = 4'd10;
    localparam [3:0]  START_ZONE    = 4'd0;
    
    // Registers
    reg [2:0] state, next_state;
    reg [31:0] trip_count;
    reg [31:0] current_time;
    reg [3:0]  current_zone;
    reg [15:0] current_cost;
    reg [15:0] dp_table_a [0:10][0:10]; // Ping-pong buffer A
    reg [15:0] dp_table_b [0:10][0:10]; // Ping-pong buffer B
    reg [15:0] dp_table_read [0:10][0:10]; // Working table for reads
    reg [15:0] dp_table_write [0:10][0:10]; // New table for writes
    reg        table_select; // 0=use A for read, 1=use B for read
    reg [31:0] last_ticket_time [0:10]; // Time when ticket was purchased for each zone
    reg        ticket_valid [0:10]; // Validity flag per zone
    reg [3:0]  calc_zone_src;
    reg [3:0]  calc_zone_dst;
    reg [15:0] min_temp;
    reg [3:0]  min_idx;
    reg [3:0]  min_loop_idx;
    reg        calc_stage;
    reg [31:0] cycle_counter;
    localparam [31:0] MAX_CYCLES = 32'd10000;
    
    // Wires for LUT lookup
    wire [15:0] lut_cost;
    wire [7:0] lut_addr;
    assign lut_addr = {calc_zone_src, calc_zone_dst};
    
    // LUT for ticket cost: 2 + |A-B|
    reg [15:0] cost_lut [0:255]; // 256 entries, 11x11 used
    integer i, j, k;
    
    // Initialize LUT
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            cost_lut[i] = 16'd0;
        end
        for (i = 0; i <= 10; i = i + 1) begin
            for (j = 0; j <= 10; j = j + 1) begin
                if (i >= j) begin
                    cost_lut[{i, j}] = 2 + (i - j);
                end else begin
                    cost_lut[{i, j}] = 2 + (j - i);
                end
            end
        end
    end
    
    assign lut_cost = cost_lut[lut_addr];
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            trip_count <= 32'd0;
            current_time <= 32'd0;
            current_zone <= 4'd0;
            current_cost <= 16'd0;
            table_select <= 1'b0;
            ready <= 1'b0;
            done <= 1'b0;
            min_cost <= 16'd0;
            calc_zone_src <= 4'd0;
            calc_zone_dst <= 4'd0;
            min_temp <= 16'd0;
            min_idx <= 4'd0;
            min_loop_idx <= 4'd0;
            calc_stage <= 1'b0;
            cycle_counter <= 32'd0;
            
            // Initialize DP tables
            for (i = 0; i <= 10; i = i + 1) begin
                for (j = 0; j <= 10; j = j + 1) begin
                    dp_table_a[i][j] <= 16'd0;
                    dp_table_b[i][j] <= 16'd0;
                    dp_table_read[i][j] <= 16'd0;
                    dp_table_write[i][j] <= 16'd0;
                end
            end
            
            // Initialize ticket times and validity
            for (k = 0; k <= 10; k = k + 1) begin
                last_ticket_time[k] <= 32'd0;
                ticket_valid[k] <= 1'b0;
            end
            
        end else begin
            state <= next_state;
            cycle_counter <= cycle_counter + 32'd1;
            
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    done <= 1'b0;
                    cycle_counter <= 32'd0;
                    if (start) begin
                        trip_count <= 32'd0;
                        table_select <= 1'b0;
                        // Initialize DP table: infinite cost except start zone
                        for (i = 0; i <= 10; i = i + 1) begin
                            for (j = 0; j <= 10; j = j + 1) begin
                                dp_table_read[i][j] <= 16'hFFFF;
                                dp_table_write[i][j] <= 16'hFFFF;
                            end
                        end
                        // Start at zone 0 with cost 0
                        dp_table_read[0][0] <= 16'd0;
                        dp_table_write[0][0] <= 16'd0;
                        
                        // Reset ticket validity
                        for (k = 0; k <= 10; k = k + 1) begin
                            ticket_valid[k] <= 1'b0;
                        end
                    end
                end
                
                FETCH: begin
                    ready <= 1'b0;
                    if (trip_valid) begin
                        current_zone <= trip_zone;
                        current_time <= trip_time;
                        calc_zone_dst <= trip_zone;
                    end
                end
                
                CALC: begin
                    if (calc_stage == 1'b0) begin
                        // First stage: read prev zone cost and check validity
                        if (calc_zone_src <= MAX_ZONE) begin
                            // Read from appropriate table
                            if (table_select == 1'b0) begin
                                current_cost <= dp_table_read[calc_zone_src][calc_zone_dst];
                            end else begin
                                current_cost <= dp_table_write[calc_zone_src][calc_zone_dst];
                            end
                            
                            // Check ticket validity
                            if (current_time - last_ticket_time[calc_zone_src] < VALIDITY_TIME) begin
                                // Ticket valid, cost stays same (0 for transition)
                                dp_table_write[calc_zone_src][calc_zone_dst] <= current_cost;
                            end else begin
                                // Buy new ticket
                                lut_cost <= cost_lut[{calc_zone_src, calc_zone_dst}];
                            end
                            
                            calc_zone_src <= calc_zone_src + 4'd1;
                        end else begin
                            calc_zone_src <= 4'd0;
                            calc_stage <= 1'b1;
                            min_temp <= 16'hFFFF;
                            min_loop_idx <= 4'd0;
                        end
                    end else begin
                        // Second stage: find minimum over all prev zones
                        if (min_loop_idx <= MAX_ZONE) begin
                            if (table_select == 1'b0) begin
                                current_cost <= dp_table_read[min_loop_idx][calc_zone_dst];
                            end else begin
                                current_cost <= dp_table_write[min_loop_idx][calc_zone_dst];
                            end
                            
                            if (current_time - last_ticket_time[min_loop_idx] < VALIDITY_TIME) begin
                                // Valid ticket, no added cost
                                if (current_cost < min_temp) begin
                                    min_temp <= current_cost;
                                    min_idx <= min_loop_idx;
                                end
                            end else begin
                                // New ticket needed
                                lut_cost <= cost_lut[{min_loop_idx, calc_zone_dst}];
                                if (current_cost + lut_cost < min_temp) begin
                                    min_temp <= current_cost + lut_cost;
                                    min_idx <= min_loop_idx;
                                end
                            end
                            min_loop_idx <= min_loop_idx + 4'd1;
                        end else begin
                            // Update DP table with min cost
                            for (i = 0; i <= 10; i = i + 1) begin
                                if (table_select == 1'b0) begin
                                    dp_table_write[calc_zone_dst][i] <= dp_table_read[calc_zone_dst][i];
                                end else begin
                                    dp_table_write[calc_zone_dst][i] <= dp_table_read[calc_zone_dst][i];
                                end
                            end
                            dp_table_write[calc_zone_dst][calc_zone_dst] <= min_temp;
                            
                            // Update ticket validity
                            if (current_time - last_ticket_time[min_idx] >= VALIDITY_TIME) begin
                                last_ticket_time[calc_zone_dst] <= current_time;
                                ticket_valid[calc_zone_dst] <= 1'b1;
                            end else begin
                                ticket_valid[calc_zone_dst] <= 1'b1;
                            end
                            
                            calc_stage <= 1'b0;
                            calc_zone_src <= 4'd0;
                        end
                    end
                end
                
                WRITE: begin
                    // Swap ping-pong buffers
                    table_select <= ~table_select;
                    trip_count <= trip_count + 32'd1;
                    ready <= 1'b1;
                    
                    // Copy write table to read table
                    for (i = 0; i <= 10; i = i + 1) begin
                        for (j = 0; j <= 10; j = j + 1) begin
                            if (table_select == 1'b0) begin
                                dp_table_b[i][j] <= dp_table_write[i][j];
                                dp_table_read[i][j] <= dp_table_write[i][j];
                            end else begin
                                dp_table_a[i][j] <= dp_table_write[i][j];
                                dp_table_read[i][j] <= dp_table_write[i][j];
                            end
                        end
                    end
                    
                    // Prepare for next trip
                    for (i = 0; i <= 10; i = i + 1) begin
                        for (j = 0; j <= 10; j = j + 1) begin
                            dp_table_write[i][j] <= 16'hFFFF;
                        end
                    end
                end
                
                DONE_STATE: begin
                    // Find minimum cost across all zones
                    ready <= 1'b0;
                    if (calc_stage == 1'b0) begin
                        // Get min from current table
                        min_temp <= 16'hFFFF;
                        min_loop_idx <= 4'd0;
                        calc_stage <= 1'b1;
                    end else begin
                        if (min_loop_idx <= MAX_ZONE) begin
                            if (table_select == 1'b0) begin
                                current_cost <= dp_table_read[min_loop_idx][calc_zone_dst];
                            end else begin
                                current_cost <= dp_table_write[min_loop_idx][calc_zone_dst];
                            end
                            if (current_cost < min_temp) begin
                                min_temp <= current_cost;
                            end
                            min_loop_idx <= min_loop_idx + 4'd1;
                        end else begin
                            min_cost <= min_temp;
                            done <= 1'b1;
                        end
                    end
                end
                
                ERROR: begin
                    ready <= 1'b0;
                    done <= 1'b0;
                    min_cost <= 16'hFFFF;
                end
                
                default: begin
                    state <= IDLE;
                    ready <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = IDLE; // Wait for first trip
                end
            end
            
            FETCH: begin
                if (trip_valid && !trip_done) begin
                    next_state = CALC;
                end else if (trip_done) begin
                    next_state = DONE_STATE;
                end
            end
            
            CALC: begin
                // Wait for calculation to complete
                if (calc_stage == 1'b1 && min_loop_idx > MAX_ZONE) begin
                    next_state = WRITE;
                end
            end
            
            WRITE: begin
                if (trip_done) begin
                    next_state = DONE_STATE;
                end else if (trip_count >= MAX_TRIPS) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = FETCH;
                end
            end
            
            DONE_STATE: begin
                if (min_loop_idx > MAX_ZONE) begin
                    next_state = DONE_STATE; // Stay in DONE
                end
            end
            
            ERROR: begin
                next_state = ERROR;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
        
        // Cycle counter safety
        if (cycle_counter >= MAX_CYCLES) begin
            next_state = ERROR;
        end
    end

endmodule