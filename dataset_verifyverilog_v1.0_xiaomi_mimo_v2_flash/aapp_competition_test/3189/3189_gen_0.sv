module wiring_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire [31:0] switch_config,
    input wire [31:0] light_config,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] NEXT = 3'd3;
    localparam [2:0] UPDATE = 3'd4;
    localparam [2:0] DONE = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;

    // Registers for counters and indices
    reg [31:0] count;
    reg [31:0] perm_counter;
    reg [3:0] photo_idx;
    reg [3:0] switch_idx;
    reg [3:0] cycle_count;

    // Permutation array (n <= 4)
    reg [1:0] perm [0:3];

    // Constants
    localparam [31:0] MOD = 32'd1000003;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Function to get a bit from packed config
    function [0:0] get_bit;
        input [31:0] cfg;
        input [3:0] photo;
        input [3:0] sw;
        begin
            get_bit = cfg[photo * 4 + sw];
        end
    endfunction

    // Function to compute factorial
    function [31:0] factorial;
        input [3:0] val;
        begin
            case (val)
                4'd0, 4'd1: factorial = 32'd1;
                4'd2: factorial = 32'd2;
                4'd3: factorial = 32'd6;
                4'd4: factorial = 32'd24;
                default: factorial = 32'd1;
            endcase
        end
    endfunction

    // Combinational logic for permutation generation
    // This must be combinational to update perm array based on perm_counter
    reg [1:0] avail_temp [0:3];
    reg [31:0] temp_counter;
    reg [3:0] temp_n;
    integer i_perm, j_perm, idx_perm;

    always @(*) begin
        temp_counter = perm_counter;
        temp_n = n;
        
        // Initialize available numbers
        for (i_perm = 0; i_perm < 4; i_perm = i_perm + 1) begin
            avail_temp[i_perm] = i_perm;
        end

        // Generate permutation using factorial number system
        for (i_perm = 0; i_perm < 4; i_perm = i_perm + 1) begin
            if (i_perm < temp_n) begin
                idx_perm = temp_counter % (4 - i_perm);
                temp_counter = temp_counter / (4 - i_perm);
                perm[i_perm] = avail_temp[idx_perm];
                
                // Remove used element
                for (j_perm = idx_perm; j_perm < 3 - i_perm; j_perm = j_perm + 1) begin
                    avail_temp[j_perm] = avail_temp[j_perm + 1];
                end
            end else begin
                perm[i_perm] = 2'd0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
                else next_state = IDLE;
            end
            INIT: begin
                next_state = CHECK;
            end
            CHECK: begin
                if (m == 4'd0) begin
                    next_state = UPDATE;
                end else if (photo_idx >= m) begin
                    next_state = UPDATE;
                end else if (switch_idx >= n) begin
                    next_state = CHECK; // Stay in CHECK, will increment photo_idx
                end else begin
                    // Check the bit comparison
                    if (get_bit(switch_config, photo_idx, switch_idx) != 
                        get_bit(light_config, photo_idx, perm[switch_idx])) begin
                        next_state = NEXT; // Mismatch, invalid permutation
                    end else begin
                        next_state = CHECK; // Match, continue checking
                    end
                end
            end
            UPDATE: begin
                next_state = NEXT;
            end
            NEXT: begin
                if (perm_counter + 32'd1 >= factorial(n)) begin
                    next_state = DONE;
                end else begin
                    next_state = CHECK;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            count <= 32'd0;
            perm_counter <= 32'd0;
            photo_idx <= 4'd0;
            switch_idx <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        count <= 32'd0;
                        perm_counter <= 32'd0;
                        photo_idx <= 4'd0;
                        switch_idx <= 4'd0;
                    end
                end

                INIT: begin
                    // Reset indices for checking
                    photo_idx <= 4'd0;
                    switch_idx <= 4'd0;
                end

                CHECK: begin
                    if (switch_idx >= n) begin
                        // All switches checked for current photo, move to next photo
                        photo_idx <= photo_idx + 1;
                        switch_idx <= 4'd0;
                    end else if (photo_idx >= m) begin
                        // All photos checked, permutation is valid
                        // Will update in next state
                    end else if (m == 4'd0) begin
                        // No photos to check, valid
                    end else if (get_bit(switch_config, photo_idx, switch_idx) != 
                               get_bit(light_config, photo_idx, perm[switch_idx])) begin
                        // Mismatch found, will go to NEXT state
                    end else begin
                        // Match, check next switch
                        switch_idx <= switch_idx + 1;
                    end
                end

                UPDATE: begin
                    count <= count + 32'd1;
                end

                NEXT: begin
                    perm_counter <= perm_counter + 32'd1;
                    photo_idx <= 4'd0;
                    switch_idx <= 4'd0;
                    if (perm_counter + 32'd1 >= factorial(n)) begin
                        result <= count % MOD;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase

            // Safety timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE) begin
                state <= DONE;
                result <= 32'd0;
            end
        end
    end

endmodule