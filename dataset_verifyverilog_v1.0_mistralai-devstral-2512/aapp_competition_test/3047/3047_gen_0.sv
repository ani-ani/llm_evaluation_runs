module proportion_puzzle(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] val_0,
    input wire [15:0] val_1,
    input wire [15:0] val_2,
    input wire [15:0] val_3,
    input wire [15:0] val_4,
    input wire [15:0] val_5,
    input wire [15:0] val_6,
    input wire [15:0] val_7,
    input wire [15:0] val_8,
    input wire [15:0] val_9,
    input wire [15:0] val_10,
    input wire [15:0] val_11,
    input wire [15:0] val_12,
    input wire [15:0] val_13,
    input wire [15:0] val_14,
    input wire [15:0] val_15,
    input wire [15:0] val_16,
    input wire [15:0] val_17,
    input wire [15:0] val_18,
    input wire [15:0] val_19,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PARSE   = 3'd1;
    localparam [2:0] SEARCH  = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;
    
    reg [2:0] state, next_state;
    reg [17:0] cycle_count;
    localparam [17:0] MAX_CYCLES = 18'd100000;

    // Known values matrix (5 monsters x 4 foods)
    reg [15:0] known [0:4][0:3];
    
    // Ratios to search
    reg [7:0] burger_sushi_ratio;
    reg [7:0] slop_drumstick_ratio;
    
    // Count of valid configurations
    reg [31:0] valid_count;
    
    // Intermediate calculations
    reg [15:0] base_burger;
    reg [15:0] base_slop;
    reg [15:0] expected_value;
    reg [15:0] calculated_value;
    
    // Flags
    reg salamander_has_burger;
    reg salamander_has_slop;
    reg salamander_has_both;
    reg valid_config;
    
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 18'd0;
            result <= 32'd0;
            done <= 1'b0;
            valid_count <= 32'd0;
            
            // Initialize known matrix
            for (i = 0; i < 5; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    known[i][j] <= 16'd0;
                end
            end
            
            burger_sushi_ratio <= 8'd0;
            slop_drumstick_ratio <= 8'd0;
            base_burger <= 16'd0;
            base_slop <= 16'd0;
            expected_value <= 16'd0;
            calculated_value <= 16'd0;
            salamander_has_burger <= 1'b0;
            salamander_has_slop <= 1'b0;
            salamander_has_both <= 1'b0;
            valid_config <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 18'd0;
                    valid_count <= 32'd0;
                    
                    if (start) begin
                        next_state <= PARSE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PARSE: begin
                    // Parse input values into known matrix
                    known[0][0] <= val_0;   // Salamander burger
                    known[0][1] <= val_1;   // Salamander slop
                    known[0][2] <= val_2;   // Salamander sushi
                    known[0][3] <= val_3;   // Salamander drumstick
                    
                    known[1][0] <= val_4;   // Yeti burger
                    known[1][1] <= val_5;   // Yeti slop
                    known[1][2] <= val_6;   // Yeti sushi
                    known[1][3] <= val_7;   // Yeti drumstick
                    
                    known[2][0] <= val_8;   // Golem burger
                    known[2][1] <= val_9;   // Golem slop
                    known[2][2] <= val_10;  // Golem sushi
                    known[2][3] <= val_11;  // Golem drumstick
                    
                    known[3][0] <= val_12;  // Imp burger
                    known[3][1] <= val_13;  // Imp slop
                    known[3][2] <= val_14;  // Imp sushi
                    known[3][3] <= val_15;  // Imp drumstick
                    
                    known[4][0] <= val_16;  // Kraken burger
                    known[4][1] <= val_17;  // Kraken slop
                    known[4][2] <= val_18;  // Kraken sushi
                    known[4][3] <= val_19;  // Kraken drumstick
                    
                    // Check what Salamander has
                    salamander_has_burger <= (known[0][0] != 16'd0);
                    salamander_has_slop <= (known[0][1] != 16'd0);
                    salamander_has_both <= salamander_has_burger & salamander_has_slop;
                    
                    next_state <= SEARCH;
                end

                SEARCH: begin
                    cycle_count <= cycle_count + 18'd1;
                    
                    // Check for timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= OUTPUT;
                    end else begin
                        // Iterate through possible ratios
                        if (burger_sushi_ratio == 8'd0 && slop_drumstick_ratio == 8'd0) begin
                            burger_sushi_ratio <= 8'd1;
                            slop_drumstick_ratio <= 8'd1;
                        end else if (slop_drumstick_ratio == 8'd256) begin
                            burger_sushi_ratio <= burger_sushi_ratio + 8'd1;
                            slop_drumstick_ratio <= 8'd1;
                            
                            // Check if we've exhausted all ratios
                            if (burger_sushi_ratio > 8'd256) begin
                                next_state <= OUTPUT;
                            end
                        end else begin
                            slop_drumstick_ratio <= slop_drumstick_ratio + 8'd1;
                        end
                        
                        // Check if current ratios are valid
                        if (burger_sushi_ratio <= 8'd256 && slop_drumstick_ratio <= 8'd256) begin
                            valid_config <= 1'b1;
                            
                            // Determine base values from Salamander
                            if (salamander_has_both) begin
                                base_burger <= known[0][0];
                                base_slop <= known[0][1];
                            end else if (salamander_has_burger) begin
                                // Need to find base_slop that works with other monsters
                                base_burger <= known[0][0];
                                base_slop <= 16'd1; // Start with 1, will be adjusted
                            end else if (salamander_has_slop) begin
                                base_burger <= 16'd1; // Start with 1, will be adjusted
                                base_slop <= known[0][1];
                            end else begin
                                base_burger <= 16'd1;
                                base_slop <= 16'd1;
                            end
                            
                            // Check consistency for all monsters
                            for (i = 0; i < 5; i = i + 1) begin
                                for (j = 0; j < 4; j = j + 1) begin
                                    if (known[i][j] != 16'd0) begin
                                        // Calculate expected value based on ratios
                                        case (j)
                                            0: expected_value <= base_burger; // burger
                                            1: expected_value <= base_slop;   // slop
                                            2: expected_value <= (base_burger * burger_sushi_ratio) / 8'd1; // sushi
                                            3: expected_value <= (base_slop * slop_drumstick_ratio) / 8'd1;   // drumstick
                                        endcase
                                        
                                        // Check if calculated matches known
                                        if (expected_value != known[i][j]) begin
                                            valid_config <= 1'b0;
                                        end
                                    end
                                end
                            end
                            
                            // If valid, increment count
                            if (valid_config) begin
                                valid_count <= valid_count + 32'd1;
                                
                                // Check for saturation
                                if (valid_count > 32'd1000) begin
                                    valid_count <= 32'd4294967295; // 0xFFFFFFFF
                                end
                            end
                        end
                    end
                end

                OUTPUT: begin
                    result <= valid_count;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule